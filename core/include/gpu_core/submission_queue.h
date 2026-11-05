#pragma once

#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>

#include "gpu_core/command_buffer.h"
#include "gpu_core/gpu_core_export.h"

namespace gpu_core {

// Thread-safe multi-producer queue that recording threads push finished
// command buffers into and a submission thread drains, like a driver's
// per-queue submit thread. This is the code the ThreadSanitizer CI job
// exists for.
class GPU_CORE_EXPORT SubmissionQueue {
public:
    // Returns the sequence number assigned to the buffer.
    uint64_t Push(CommandBuffer buffer);

    // Blocks until a buffer is available or Close() is called.
    std::optional<CommandBuffer> Pop();

    void Close();
    std::size_t Size() const;

private:
    mutable std::mutex mutex_;
    std::condition_variable ready_;
    std::deque<CommandBuffer> buffers_;
    uint64_t next_sequence_ = 0;
    bool closed_ = false;
};

}  // namespace gpu_core
