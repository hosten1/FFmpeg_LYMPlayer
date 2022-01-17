#include "lymcodationlock.h"

LYMCodationLock::LYMCodationLock():mutex_(SDL_CreateMutex()),cond_(SDL_CreateCond())
{

}
LYMCodationLock::~LYMCodationLock(){
    SDL_DestroyCond(cond_);
    SDL_DestroyMutex(mutex_);
}
void LYMCodationLock::lock(){
    SDL_LockMutex(mutex_);
}
void LYMCodationLock::unlock(){
    SDL_UnlockMutex(mutex_);
}
void LYMCodationLock::wait(){
    SDL_CondWait(cond_,mutex_);
}
void LYMCodationLock::signal(){
    SDL_CondSignal(cond_);
}
void LYMCodationLock::broadcastSig(){
    SDL_CondBroadcast(cond_);
}
