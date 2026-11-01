#!/usr/bin/env bash
# ==============================================================================
# 🖥️ TMUX 3-SERVER FLIP & CONTROL SCRIPT (Run on your MacBook Workstation)
# ==============================================================================
# Why did Pane 1 give "Permission denied" earlier?
# Because your MacBook runs Anaconda `(base)` in `.zshrc` when opening a new pane,
# which collided with `tmux send-keys`, and macOS SSH tried public keys first!
#
# Fix:
# 1. We force `-o PreferredAuthentications=password -o PubkeyAuthentication=no`
# 2. We pass the SSH command directly to `new-session` and `split-window` so it
#    doesn't collide with `.zshrc` / `(base)` startup!
# ==============================================================================

SESSION="northpoint-cluster"
SSH_CMD="sshpass -p northpoint ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no -o LogLevel=ERROR"

# Get current MacBook terminal dimensions (fallback to 160x45 if not detected)
TERM_COLS=$(tput cols 2>/dev/null || echo 160)
TERM_LINES=$(tput lines 2>/dev/null || echo 45)

# Kill old session if it already exists so we start fresh
tmux kill-session -t "$SESSION" 2>/dev/null

echo "🚀 Launching tmux workstation session: $SESSION (${TERM_COLS}x${TERM_LINES}) ..."

# ------------------------------------------------------------------------------
# WINDOW 0: 3 Side-by-Side Columns (Server 1 | Server 2 | Server 3)
# ------------------------------------------------------------------------------
# Pane 0 (Left Column): Server 1 (Port 2221)
tmux new-session -d -s "$SESSION" -n "all-3-servers" -x "$TERM_COLS" -y "$TERM_LINES" \
  "bash -c '$SSH_CMD -p 2221 ansible@127.0.0.1; exec bash'"

# Enable mouse clicking & dragging on your MacBook
tmux set-option -t "$SESSION" mouse on

# Make active pane border bright green so you always see which server you are on
tmux set-option -t "$SESSION" pane-active-border-style "fg=brightgreen,bold"
tmux set-option -t "$SESSION" pane-border-status top
tmux set-option -t "$SESSION" pane-border-format " #[fg=yellow,bold]🖥️ Pane #P "

# Pane 1 (Middle Column): Split Side-by-Side (-h) for Server 2 (Port 2222)
tmux split-window -h -t "$SESSION:all-3-servers.0" \
  "bash -c '$SSH_CMD -p 2222 ansible@127.0.0.1; exec bash'"

# Pane 2 (Right Column): Split Side-by-Side (-h) for Server 3 (Port 2223)
tmux split-window -h -t "$SESSION:all-3-servers.1" \
  "bash -c '$SSH_CMD -p 2223 ansible@127.0.0.1; exec bash'"

# Arrange all 3 servers into 3 equal side-by-side columns!
tmux select-layout -t "$SESSION:all-3-servers" even-horizontal

# ------------------------------------------------------------------------------
# WINDOW 1, 2, 3: Full-Screen Individual Server Tabs to Flip Between
# ------------------------------------------------------------------------------
tmux new-window -t "$SESSION" -n "1-server1" "bash -c '$SSH_CMD -p 2221 ansible@127.0.0.1; exec bash'"
tmux new-window -t "$SESSION" -n "2-server2" "bash -c '$SSH_CMD -p 2222 ansible@127.0.0.1; exec bash'"
tmux new-window -t "$SESSION" -n "3-server3" "bash -c '$SSH_CMD -p 2223 ansible@127.0.0.1; exec bash'"

# Start on Window 0 (All 3 servers side-by-side) and focus Pane 0 (Server 1)
tmux select-window -t "$SESSION:all-3-servers"
tmux select-pane -t "$SESSION:all-3-servers.0"

# Attach your MacBook terminal to the tmux session
exec tmux attach-session -t "$SESSION"
