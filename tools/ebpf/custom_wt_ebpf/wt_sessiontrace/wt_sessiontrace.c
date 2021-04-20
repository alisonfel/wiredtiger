#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

#include <uapi/linux/ptrace.h>

struct session_info_t {
    char config[300];
    u64 timestamp_ns;
    u64 tgid_pid;
    u64 session_addr;
};

struct session_config_t {
    char config[300];
    void *session_addr;
    u64 tgid_pid;
};

struct txn_info_t {
    u64 session;
    u64 timestamp_ns;
    u64 tgid_pid;
    char config[300];
};

struct txn_config_t {
    char config[300];
    u64 session;
};

BPF_HASH(sessions, u64, struct session_info_t, 1000000);
BPF_HASH(session_configs, u64, struct session_config_t, 1000000);
BPF_HASH(txns, u64, struct txn_info_t, 1000000);
BPF_HASH(txn_configs, u64, struct txn_config_t, 1000000);

static inline int
txn_begin_enter(struct pt_regs *ctx)
{
    void *session_addr;
    struct txn_config_t conf = {0};

    session_addr = (void *)PT_REGS_PARM1(ctx);
    bpf_probe_read(&conf.config, sizeof(conf.config), (void *)PT_REGS_PARM2(ctx));
    conf.session = (u64)session_addr;

    u64 pid = bpf_get_current_pid_tgid();
    txn_configs.update(&pid, &conf);
    return 0;
}

static inline int
txn_begin_ret(struct pt_regs *ctx)
{
    u64 pid = bpf_get_current_pid_tgid();
    struct txn_config_t *conf = txn_configs.lookup(&pid);
    if (conf == 0) {
        return 0;
    }
    struct txn_info_t info = {0};
    int ret = PT_REGS_RC(ctx);
    if (ret == 0) {
        info.timestamp_ns = bpf_ktime_get_ns();
        info.tgid_pid = pid;
        info.session = conf->session;
        bpf_probe_read(&info.config, sizeof(info.config), (void *)conf->config);
        txns.update(&info.session, &info);
    }
    txn_configs.delete(&pid);
    return 0;
}

static inline int
txn_close(struct pt_regs *ctx, int code, u64 session)
{
    if (code == 0) {
        struct txn_info_t *info = txns.lookup(&session);
        if (info == 0)
            return 0;
        txns.delete(&session);
    }
    return 0;
}

int
session_create_enter(struct pt_regs *ctx, void *conn, void *event_handler, const char *config,
  bool open_metadata, void **sessionp)
{
    u64 pid = bpf_get_current_pid_tgid();
    struct session_config_t conf = {0};
    bpf_probe_read(&conf.config, sizeof(conf.config), (void *)PT_REGS_PARM3(ctx));
    conf.session_addr = sessionp;
    conf.tgid_pid = pid;
    session_configs.update(&pid, &conf);
    return 0;
}

int
session_create_ret(struct pt_regs *ctx)
{
    u64 pid = bpf_get_current_pid_tgid();
    struct session_config_t *conf = session_configs.lookup(&pid);
    if (conf == 0) {
        return 0;
    }
    struct session_info_t info = {0};
    int ret = PT_REGS_RC(ctx);
    if (ret == 0) {
        info.timestamp_ns = bpf_ktime_get_ns();
        info.tgid_pid = pid;
        bpf_probe_read(&info.config, sizeof(info.config), (void *)conf->config);
        bpf_probe_read(&info.session_addr, sizeof(info.session_addr), (void *)conf->session_addr);
        sessions.update(&info.session_addr, &info);
    }
    session_configs.delete(&pid);
    return 0;
}

static inline int
session_close(struct pt_regs *ctx)
{
    int ret = PT_REGS_RC(ctx);
    if (ret == 0) {
        void *session_addr;
        bpf_probe_read(&session_addr, sizeof(session_addr), (void *)PT_REGS_PARM1(ctx));
        u64 addr = (u64)session_addr;
        struct session_info_t *info = sessions.lookup(&addr);
        if (info == 0)
            return 0;
        sessions.delete(&addr);
    }
    return 0;
}

int
wt_begin_transaction_enter(struct pt_regs *ctx)
{
    return txn_begin_enter(ctx);
}

int
wt_begin_transaction_ret(struct pt_regs *ctx)
{
    return txn_begin_ret(ctx);
}

int
wt_transaction_rollback(struct pt_regs *ctx)
{
    return txn_close(ctx, PT_REGS_RC(ctx), (u64)PT_REGS_PARM1(ctx));
}

int
wt_transaction_commit(struct pt_regs *ctx)
{
    return txn_close(ctx, PT_REGS_RC(ctx), (u64)PT_REGS_PARM1(ctx));
}

int
wt_session_close(struct pt_regs *ctx)
{
    return session_close(ctx);
}
