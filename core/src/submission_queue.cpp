#include "gpu_core/submission_queue.h"

#include <utility>

namespace gpu_core {

uint64_t SubmissionQueue::Push(CommandBuffer buffer) {
    uint64_t sequence = 0;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        sequence = next_sequence_++;
        buffers_.push_back(std::move(buffer));
    }
    ready_.notify_one();
    return sequence;
}

std::optional<CommandBuffer> SubmissionQueue::Pop() {
    std::unique_lock<std::mutex> lock(mutex_);
    ready_.wait(lock, [this] { return closed_ || !buffers_.empty(); });
    if (buffers_.empty()) {
        return std::nullopt;
    }
    CommandBuffer buffer = std::move(buffers_.front());
    buffers_.pop_front();
    return buffer;
}

void SubmissionQueue::Close() {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        closed_ = true;
    }
    ready_.notify_all();
}

std::size_t SubmissionQueue::Size() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return buffers_.size();
}

}  // namespace gpu_core
