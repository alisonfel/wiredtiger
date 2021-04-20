#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

struct alloc_init_t {
    u64 size;
    void *retp;
};

struct alloc_info_t {
    u64 size;
    u64 timestamp_ns;
    int stack_id;
    u64 tgid_pid;
};

BPF_HASH(sizes, u64, struct alloc_init_t, 1000000);
BPF_HASH(allocs, u64, struct alloc_info_t, 1000000);
BPF_STACK_TRACE(stack_traces, 10240);

static inline int
gen_alloc_enter(struct pt_regs *ctx, size_t alloc_size, void *retp)
{
    // Sample every ~100 allocation
    u64 ts = bpf_ktime_get_ns();
    if (ts % 100 != 0)
        return 0;

    struct alloc_init_t init = {0};
    u64 pid = bpf_get_current_pid_tgid();
    init.size = alloc_size;
    init.retp = retp;
    sizes.update(&pid, &init);
    return 0;
}

static inline int
gen_alloc_exit2(struct pt_regs *ctx)
{
    u64 pid = bpf_get_current_pid_tgid();
    struct alloc_init_t *init = sizes.lookup(&pid);
    struct alloc_info_t info = {0};
    if (init == 0)
        return 0; // missed alloc entry
    void *address;
    bpf_probe_read(&address, sizeof(address), init->retp);
    u64 addr = (u64)address;
    info.size = init->size;
    sizes.delete(&pid);
    if (address != 0) {
        info.timestamp_ns = bpf_ktime_get_ns();
        info.stack_id = stack_traces.get_stackid(ctx, BPF_F_USER_STACK);
        info.tgid_pid = pid;
        allocs.update(&addr, &info);
    }
    return 0;
}

static inline int
gen_free_enter(struct pt_regs *ctx, void *address)
{
    u64 addr = (u64)address;
    struct alloc_info_t *info = allocs.lookup(&addr);
    if (info == 0)
        return 0;
    allocs.delete(&addr);
    return 0;
}

int
wt_malloc_enter(struct pt_regs *ctx, void *session, size_t bytes_to_allocate, void *retp)
{
    return gen_alloc_enter(ctx, bytes_to_allocate, retp);
}

int
wt_malloc_exit(struct pt_regs *ctx)
{
    return gen_alloc_exit2(ctx);
}

int
wt_free_enter(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM2(ctx));
    return gen_free_enter(ctx, address);
}

int
wt_calloc_enter(struct pt_regs *ctx, void *session, size_t number, size_t size, void *retp)
{
    return gen_alloc_enter(ctx, number * size, retp);
}

int
wt_calloc_exit(struct pt_regs *ctx)
{
    return gen_alloc_exit2(ctx);
}

int
wt_realloc_enter(struct pt_regs *ctx, void *session, size_t *bytes_allocated_ret,
  size_t bytes_to_allocate, void *retp)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), retp);
    gen_free_enter(ctx, address);
    return gen_alloc_enter(ctx, bytes_to_allocate, retp);
}

int
wt_realloc_exit(struct pt_regs *ctx)
{
    return gen_alloc_exit2(ctx);
}
