#include <iostream>
#include <thread>
#include <future>
#include <mutex>
#include <queue>
#include <functional>
#include <chrono>
#include <condition_variable>

class TaskProcessor {
    std::mutex queue_mutex;
    std::condition_variable cv;
    std::queue<std::function<void()>> tasks;
    bool stop_flag = false;
    std::thread worker_thread;

public:
    TaskProcessor() : worker_thread([this] { run_worker(); }) {}

    ~TaskProcessor() {
        {
            std::lock_guard<std::mutex> lock(queue_mutex);
            stop_flag = true;
        }
        cv.notify_all();
        if (worker_thread.joinable()) {
            worker_thread.join();
        }
    }

    template <typename Func>
    auto submit(Func f) -> std::future<decltype(f())> {
        using ReturnType = decltype(f());
        
        auto task = std::make_shared<std::packaged_task<ReturnType()>>(f);
        
        std::future<ReturnType> result = task->get_future();
        
        {
            std::lock_guard<std::mutex> lock(queue_mutex);
            tasks.push([task]() { (*task)(); });
        }
        
        cv.notify_one();
        return result;
    }

private:
    void run_worker() {
        while (true) {
            std::function<void()> task;
            {
                std::unique_lock<std::mutex> lock(queue_mutex);
                cv.wait(lock, [this] { 
                    return !tasks.empty() || stop_flag; 
                });
                
                if (stop_flag && tasks.empty()) return;
                
                task = std::move(tasks.front());
                tasks.pop();
            }
            task();
        }
    }
};

// 示例耗时函数
int long_running_task(int a, int b) {
    std::this_thread::sleep_for(std::chrono::seconds(2));
    return a + b;
}

int main() {
    TaskProcessor processor; // 线程A的任务处理器
    
    // 线程B的操作
    std::future<int> result = processor.submit([] {
        return long_running_task(10, 20);
    });
    
    std::cout << "ThreadB: Waiting for result..." << std::endl;
    std::cout << "Result: " << result.get() << std::endl;
    std::cout << "ThreadB: Got result!" << std::endl;

    return 0;
}
