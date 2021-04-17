#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

struct alloc_info_t {
    u64 size;
    u64 timestamp_ns;
    int stack_id;
    u64 tgid_pid;
};

BPF_HASH(sizes, u64);
BPF_HASH(allocs, u64, struct alloc_info_t, 1000000);
BPF_STACK_TRACE(stack_traces, 10240);

static inline int
gen_alloc_enter(struct pt_regs *ctx, size_t alloc_size)
{
    u64 pid = bpf_get_current_pid_tgid();
    u64 size64 = alloc_size;
    sizes.update(&pid, &size64);
    return 0;
}

static inline int
gen_alloc_exit2(struct pt_regs *ctx, u64 address)
{
    u64 pid = bpf_get_current_pid_tgid();
    u64 *size64 = sizes.lookup(&pid);
    struct alloc_info_t info = {0};
    if (size64 == 0)
        return 0; // missed alloc entry
    info.size = *size64;
    sizes.delete(&pid);
    if (address != 0) {
        info.timestamp_ns = bpf_ktime_get_ns();
        info.stack_id = stack_traces.get_stackid(ctx, BPF_F_USER_STACK);
        info.tgid_pid = pid;
        allocs.update(&address, &info);
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
wt_malloc_enter(struct pt_regs *ctx)
{
    size_t alloc_size;
    return gen_alloc_enter(ctx, PT_REGS_PARM2(ctx));
}

int
wt_malloc_exit(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM3(ctx));
    return gen_alloc_exit2(ctx, (u64)address);
}

int
wt_free_enter(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM2(ctx));
    return gen_free_enter(ctx, address);
}

int
wt_calloc_enter(struct pt_regs *ctx)
{
    return gen_alloc_enter(ctx, PT_REGS_PARM2(ctx) * PT_REGS_PARM3(ctx));
}

int
wt_calloc_exit(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM4(ctx));
    return gen_alloc_exit2(ctx, (u64)address);
}

int
wt_realloc_enter(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM4(ctx));
    gen_free_enter(ctx, address);
    return gen_alloc_enter(ctx, PT_REGS_PARM3(ctx));
}

int
wt_realloc_exit(struct pt_regs *ctx)
{
    void *address;
    bpf_probe_read(&address, sizeof(address), (void *)PT_REGS_PARM4(ctx));
    return gen_alloc_exit2(ctx, (u64)address);
}
