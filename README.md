# iOSPrinciple_Runloop
Principle Runloop

### 一. RunLoop简介
运行循环，在程序运行过程中循环做一些事情，如果没有Runloop程序执行完毕就会立即退出，如果有Runloop程序会一直运行，并且时时刻刻在等待用户的输入操作。RunLoop可以在需要的时候自己跑起来运行，在没有操作的时候就停下来休息。充分节省CPU资源，提高程序性能。

### 二. RunLoop基本作用
* 1.保持程序持续运行，程序一启动就会开一个主线程，主线程一开起来就会跑一个主线程对应的RunLoop,RunLoop保证主线程不会被销毁，也就保证了程序的持续运行
* 2.处理App中的各种事件（比如：触摸事件，定时器事件，Selector事件等）
* 3.节省CPU资源，提高程序性能，程序运行起来时，当什么操作都没有做的时候，RunLoop就告诉CPU，现在没有事情做，我要去休息，这时CPU就会将其资源释放出来去做其他的事情，当有事情做的时候RunLoop就会立马起来去做事情

我们先通过API内一张图片来简单看一下RunLoop内部运行原理

![](http://og1yl0w9z.bkt.clouddn.com/18-5-8/72800040.jpg)

通过图片可以看出，RunLoop在跑圈过程中，当接收到Input sources 或者 Timer sources时就会交给对应的处理方去处理。当没有事件消息传入的时候，RunLoop就休息了。这里只是简单的理解一下这张图，接下来我们来了解RunLoop对象和其一些相关类，来更深入的理解RunLoop运行流程。

### 三. RunLoop在哪里开启
UIApplicationMain函数内启动了Runloop，程序不会马上退出，而是保持运行状态。因此每一个应用必须要有一个runloop，我们知道主线程一开起来，就会跑一个和主线程对应的RunLoop，那么RunLoop一定是在程序的入口main函数中开启。

```objc
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

进入UIApplicationMain

```c
UIKIT_EXTERN int UIApplicationMain(int argc, char *argv[], NSString * __nullable principalClassName, NSString * __nullable delegateClassName);
```

我们发现它返回的是一个int数，那么我们对main函数做一些修改

```objc
int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSLog(@"开始");
        int re = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        NSLog(@"结束");
        return re;
    }
}
```

运行程序，我们发现只会打印开始，并不会打印结束，这说明在UIApplicationMain函数中，开启了一个和主线程相关的RunLoop，导致UIApplicationMain不会返回，一直在运行中，也就保证了程序的持续运行。
我们来看到RunLoop的源码

```c
// 用DefaultMode启动
void CFRunLoopRun(void) {    /* DOES CALLOUT */
    int32_t result;
    do {
        result = CFRunLoopRunSpecific(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 1.0e10, false);
        CHECK_FOR_FORK();
    } while (kCFRunLoopRunStopped != result && kCFRunLoopRunFinished != result);
}
```

我们发现RunLoop确实是do while通过判断result的值实现的。因此，我们可以把RunLoop看成一个死循环。如果没有RunLoop，UIApplicationMain函数执行完毕之后将直接返回，也就没有程序持续运行一说了。

### 四. RunLoop对象
* Fundation框架（基于CFRunLoopRef的封装） NSRunLoop 对象
* CoreFoundation CFRunLoopRef 对象

因为Fundation框架是基于CFRunLoopRef的一层OC封装，这里我们主要研究CFRunLoopRef源码

#### 如何获得RunLoop对象
Foundation
```objc
[NSRunLoop currentRunLoop]; // 获得当前线程的RunLoop对象
[NSRunLoop mainRunLoop]; // 获得主线程的RunLoop对象
```

Core Foundation
```objc
CFRunLoopGetCurrent(); // 获得当前线程的RunLoop对象
CFRunLoopGetMain(); // 获得主线程的RunLoop对象
```

### 五. RunLoop和线程间的关系
* 1.每条线程都有唯一的一个与之对应的RunLoop对象
* 2.RunLoop保存在一个全局的Dictionary里，线程作为key,RunLoop作为value
* 3.主线程的RunLoop已经自动创建好了，子线程的RunLoop需要主动创建
* 4.RunLoop在第一次获取时创建，在线程结束时销毁

#### 通过源码查看上述对应
```c
// 拿到当前Runloop 调用_CFRunLoopGet0
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CHECK_FOR_FORK();
    CFRunLoopRef rl = (CFRunLoopRef)_CFGetTSD(__CFTSDKeyRunLoop);
    if (rl) return rl;
    return _CFRunLoopGet0(pthread_self());
}

// 查看_CFRunLoopGet0方法内部
CF_EXPORT CFRunLoopRef _CFRunLoopGet0(pthread_t t) {
    if (pthread_equal(t, kNilPthreadT)) {
        t = pthread_main_thread_np();
    }
    __CFLock(&loopsLock);
    if (!__CFRunLoops) {
        __CFUnlock(&loopsLock);
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        // 根据传入的主线程获取主线程对应的RunLoop
        CFRunLoopRef mainLoop = __CFRunLoopCreate(pthread_main_thread_np());
        // 保存主线程 将主线程-key和RunLoop-Value保存到字典中
        CFDictionarySetValue(dict, pthreadPointer(pthread_main_thread_np()), mainLoop);
        if (!OSAtomicCompareAndSwapPtrBarrier(NULL, dict, (void * volatile *)&__CFRunLoops)) {
            CFRelease(dict);
        }
        CFRelease(mainLoop);
        __CFLock(&loopsLock);
    }

    // 从字典里面拿，将线程作为key从字典里获取一个loop
    CFRunLoopRef loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
    __CFUnlock(&loopsLock);

    // 如果loop为空，则创建一个新的loop，所以runloop会在第一次获取的时候创建
    if (!loop) {  
        CFRunLoopRef newLoop = __CFRunLoopCreate(t);
        __CFLock(&loopsLock);
        loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));

        // 创建好之后，以线程为key runloop为value，一对一存储在字典中，下次获取的时候，则直接返回字典内的runloop
        if (!loop) { 
            CFDictionarySetValue(__CFRunLoops, pthreadPointer(t), newLoop);
            loop = newLoop;
        }
        // don't release run loops inside the loopsLock, because CFRunLoopDeallocate may end up taking it
        __CFUnlock(&loopsLock);
        CFRelease(newLoop);
    }
    if (pthread_equal(t, pthread_self())) {
        _CFSetTSD(__CFTSDKeyRunLoop, (void *)loop, NULL);
        if (0 == _CFGetTSD(__CFTSDKeyRunLoopCntr)) {
            _CFSetTSD(__CFTSDKeyRunLoopCntr, (void *)(PTHREAD_DESTRUCTOR_ITERATIONS-1), (void (*)(void *))__CFFinalizeRunLoop);
        }
    }
    return loop;
}
```

从上面的代码可以看出，线程和 RunLoop 之间是一一对应的，其关系是保存在一个 Dictionary 里。所以我们创建子线程RunLoop时，只需在子线程中获取当前线程的RunLoop对象即可[NSRunLoop currentRunLoop];如果不获取，那子线程就不会创建与之相关联的RunLoop，并且只能在一个线程的内部获取其 RunLoop
[NSRunLoop currentRunLoop];方法调用时，会先看一下字典里有没有存子线程相对用的RunLoop，如果有则直接返回RunLoop，如果没有则会创建一个，并将与之对应的子线程存入字典中。当线程结束时，RunLoop会被销毁。

### 六. RunLoop结构体

通过源码我们找到__CFRunLoop结构体
```c
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;            /* locked for accessing mode list */
    __CFPort _wakeUpPort;            // used for CFRunLoopWakeUp 
    Boolean _unused;
    volatile _per_run_data *_perRunData;              // reset for runs of the run loop
    pthread_t _pthread;
    uint32_t _winthread;
    CFMutableSetRef _commonModes;
    CFMutableSetRef _commonModeItems;
    CFRunLoopModeRef _currentMode;
    CFMutableSetRef _modes;
    struct _block_item *_blocks_head;
    struct _block_item *_blocks_tail;
    CFAbsoluteTime _runTime;
    CFAbsoluteTime _sleepTime;
    CFTypeRef _counterpart;
};
```
除一些记录性属性外，主要来看一下以下两个成员变量
```c
CFRunLoopModeRef _currentMode;
CFMutableSetRef _modes;
```
CFRunLoopModeRef 其实是指向__CFRunLoopMode结构体的指针，__CFRunLoopMode结构体源码如下
```c
typedef struct __CFRunLoopMode *CFRunLoopModeRef;
struct __CFRunLoopMode {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;    /* must have the run loop locked before locking this */
    CFStringRef _name;
    Boolean _stopped;
    char _padding[3];
    CFMutableSetRef _sources0;
    CFMutableSetRef _sources1;
    CFMutableArrayRef _observers;
    CFMutableArrayRef _timers;
    CFMutableDictionaryRef _portToV1SourceMap;
    __CFPortSet _portSet;
    CFIndex _observerMask;
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;
    dispatch_queue_t _queue;
    Boolean _timerFired; // set to true by the source when a timer has fired
    Boolean _dispatchTimerArmed;
#endif
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;
    Boolean _mkTimerArmed;
#endif
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;
    void (*_msgPump)(void);
#endif
    uint64_t _timerSoftDeadline; /* TSR */
    uint64_t _timerHardDeadline; /* TSR */
};
```
主要查看以下成员变量
```c
CFMutableSetRef _sources0;
CFMutableSetRef _sources1;
CFMutableArrayRef _observers;
CFMutableArrayRef _timers;
```
通过上面分析我们知道，CFRunLoopModeRef代表RunLoop的运行模式，一个RunLoop包含若干个Mode，每个Mode又包含若干个Source0/Source1/Timer/Observer，而RunLoop启动时只能选择其中一个Mode作为currentMode。

### Source1/Source0/Timers/Observer分别代表什么
#### 1. Source1 : 基于Port的线程间通信

#### 2. Source0 : 触摸事件，PerformSelectors

我们通过代码验证一下

```objc
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    NSLog(@"点击了屏幕");
}
```
打断点之后打印堆栈信息，当xcode工具区打印的堆栈信息不全时，可以在控制台通过“bt”指令打印完整的堆栈信息，由堆栈信息中可以发现，触摸事件确实是会触发Source0事件。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-8/31305502.jpg)

同样的方式验证performSelector堆栈信息

```objc
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    [self performSelectorOnMainThread:@selector(test) withObject:nil waitUntilDone:YES];
});
```
可以发现PerformSelectors同样是触发Source0事件

![](http://og1yl0w9z.bkt.clouddn.com/18-5-8/88088733.jpg)

其实，当我们触发了事件（触摸/锁屏/摇晃等）后，由IOKit.framework生成一个 IOHIDEvent事件

> IOKit是苹果的硬件驱动框架，由它进行底层接口的抽象封装与系统进行交互传递硬件感应的事件，并专门处理用户交互设备，由IOHIDServices和IOHIDDisplays两部分组成，其中IOHIDServices是专门处理用户交互的，它会将事件封装成IOHIDEvents对象，

接着用mach port转发给需要的App进程，随后 Source1就会接收IOHIDEvent，之后再回调__IOHIDEventSystemClientQueueCallback()，__IOHIDEventSystemClientQueueCallback()内触发Source0，Source0 再触发 _UIApplicationHandleEventQueue()。所以触摸事件看到是在 Source0 内的。

#### 3. Timers : 定时器，NSTimer

通过代码验证
```objc
[NSTimer scheduledTimerWithTimeInterval:3.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
    NSLog(@"NSTimer ---- timer调用了");
}];
```
打印完整堆栈信息

![](http://og1yl0w9z.bkt.clouddn.com/18-5-8/39044079.jpg)

#### 4. Observer : 监听器，用于监听RunLoop的状态














