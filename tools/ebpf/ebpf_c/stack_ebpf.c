#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct entry_t {
    u64 id;
    u64 args[6];
    u64 start_ns;
};

struct data_t {
    u64 id;
    u64 tgid_pid;
    u64 start_ns;
    u64 duration_ns;
    u64 retval;
    char comm[TASK_COMM_LEN];
    u64 args[6];
    int user_stack_id;
};

BPF_HASH(entryinfo, u64, struct entry_t);
BPF_PERF_OUTPUT(events);
BPF_STACK_TRACE(stacks, 2048);

static int
trace_entry(struct pt_regs *ctx, int id)
{
    u64 tgid_pid = bpf_get_current_pid_tgid();
    u32 tgid = tgid_pid >> 32;
    u32 pid = tgid_pid;
    struct entry_t entry = {};
    entry.start_ns = bpf_ktime_get_ns();
    entry.id = id;
    entry.args[0] = PT_REGS_PARM1(ctx);
    entry.args[1] = PT_REGS_PARM2(ctx);
    entry.args[2] = PT_REGS_PARM3(ctx);
    entry.args[3] = PT_REGS_PARM4(ctx);
    entry.args[4] = PT_REGS_PARM5(ctx);
    entry.args[5] = PT_REGS_PARM6(ctx);
    entryinfo.update(&tgid_pid, &entry);
    return 0;
}

int
trace_return(struct pt_regs *ctx)
{
    struct entry_t *entryp;
    u64 tgid_pid = bpf_get_current_pid_tgid();
    entryp = entryinfo.lookup(&tgid_pid);
    if (entryp == 0) {
        return 0;
    }
    u64 delta_ns = bpf_ktime_get_ns() - entryp->start_ns;
    entryinfo.delete(&tgid_pid);

    // Min time threshold to report function+stack
    if (delta_ns < DURATION_NS) {
        return 0;
    }

    struct data_t data = {};
    data.id = entryp->id;
    data.tgid_pid = tgid_pid;
    data.retval = PT_REGS_RC(ctx);
    data.user_stack_id = stacks.get_stackid(ctx, BPF_F_USER_STACK);
    data.duration_ns = delta_ns;
    bpf_probe_read(&data.args[0], sizeof(data.args), entryp->args);
    bpf_get_current_comm(&data.comm, sizeof(data.comm));
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
