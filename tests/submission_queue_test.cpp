#include <gtest/gtest.h>

#include <atomic>
#include <optional>
#include <thread>
#include <vector>

#include "gpu_core/submission_queue.h"

namespace {

gpu_core::CommandBuffer MakeBuffer(uint32_t id) {
    gpu_core::CommandBuffer buffer;
    buffer.Record({gpu_core::CommandType::kDraw, {id}});
    return buffer;
}

}  // namespace

TEST(SubmissionQueueTest, PopsInFifoOrder) {
    gpu_core::SubmissionQueue queue;
    EXPECT_EQ(queue.Push(MakeBuffer(1)), 0u);
    EXPECT_EQ(queue.Push(MakeBuffer(2)), 1u);

    const std::optional<gpu_core::CommandBuffer> first = queue.Pop();
    if (!first.has_value()) {
        FAIL() << "queue returned nothing";
    } else {
        EXPECT_EQ(first->Commands()[0].args[0], 1u);
    }
    EXPECT_EQ(queue.Size(), 1u);
}

TEST(SubmissionQueueTest, PopReturnsEmptyAfterCloseAndDrain) {
    gpu_core::SubmissionQueue queue;
    queue.Push(MakeBuffer(1));
    queue.Close();

    EXPECT_TRUE(queue.Pop().has_value());
    EXPECT_FALSE(queue.Pop().has_value());
}

// Many recording threads, one submit thread: the shape of a real driver
// queue. Run under ThreadSanitizer in CI to catch data races.
TEST(SubmissionQueueTest, ConcurrentProducersLoseNothing) {
    constexpr int kProducers = 8;
    constexpr int kBuffersPerProducer = 500;

    gpu_core::SubmissionQueue queue;
    std::atomic<int> consumed{0};
    std::thread consumer([&] {
        while (queue.Pop().has_value()) {
            consumed.fetch_add(1, std::memory_order_relaxed);
        }
    });

    std::vector<std::thread> producers;
    producers.reserve(kProducers);
    for (int p = 0; p < kProducers; ++p) {
        producers.emplace_back([&queue, p] {
            for (int i = 0; i < kBuffersPerProducer; ++i) {
                queue.Push(MakeBuffer(static_cast<uint32_t>(p * kBuffersPerProducer + i)));
            }
        });
    }
    for (auto& producer : producers) {
        producer.join();
    }
    queue.Close();
    consumer.join();

    EXPECT_EQ(consumed.load(), kProducers * kBuffersPerProducer);
}
