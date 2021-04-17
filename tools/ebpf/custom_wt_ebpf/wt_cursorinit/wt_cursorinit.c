#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

struct data_t {
    char uri[300];
};

BPF_PERF_OUTPUT(events);

int
probe_cursorinit(struct pt_regs *ctx)
{
    struct data_t data = {};
    bpf_probe_read(&data.uri, sizeof(data.uri), (void *)PT_REGS_PARM2(ctx));
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
