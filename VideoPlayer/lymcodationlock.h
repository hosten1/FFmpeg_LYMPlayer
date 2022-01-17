#ifndef LYMCODATIONLOCK_H
#define LYMCODATIONLOCK_H

#include "SDL2/SDL.h"

class LYMCodationLock
{
public:
    LYMCodationLock();
    ~LYMCodationLock();

    void lock();
    void unlock();
    void wait();
    void signal();
    void broadcastSig();
private:
    SDL_mutex *mutex_;
    SDL_cond  *cond_;
};

#endif // LYMCODATIONLOCK_H
