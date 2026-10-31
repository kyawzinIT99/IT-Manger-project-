#!/usr/bin/env bash
# ==============================================================================
# 🖥️ TMUX 3-SERVER FLIP & CONTROL SCRIPT (Run on your MacBook Workstation)
# ==============================================================================
# What does this script do?
# It opens a single `tmux` session on your MacBook named `northpoint-cluster`
# with TWO modes so you can easily flip between all 3 Docker servers:
#
#   Window 1 ("split-3-servers"):
#     Splits your MacBook screen into 3 live SSH panes (Server 1, Server 2, Server 3)
#     with SYNCHRONIZED typing available!
#
#   Window 2, 3, 4 ("server1", "server2", "server3"):
#     Dedicated full-screen windows for each individual server so you can flip
#     between them using Ctrl+b then 1, 2, 3, or 4!
# ==============================================================================

SESSION="northpoint-cluster"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Check if tmux is installed on the MacBook
if ! command -v tmux &> /dev/null; then
  echo "❌ tmux is not installed on your MacBook yet!"
  echo "👉 Run: brew install tmux"
  exit 1
fi

# Kill old session if it already exists so we start fresh
tmux kill-session -t "$SESSION" 2>/dev/null

echo "🚀 Launching tmux workstation session: $SESSION ..."

# ------------------------------------------------------------------------------
# WINDOW 0: 3-Pane Split View (All 3 Servers visible at once!)
# ------------------------------------------------------------------------------
tmux new-session -d -s "$SESSION" -n "all-3-servers"

# Enable mouse clicking in this tmux session on your MacBook
tmux set-option -t "$SESSION" mouse on

# Pane 0 (Top): Connect to Server 1 (Port 2221)
tmux send-keys -t "$SESSION:all-3-servers.0" "ssh $SSH_OPTS -p 2221 ansible@127.0.0.1" C-m

# Split horizontally for Server 2 (Port 2222)
tmux split-window -v -t "$SESSION:all-3-servers"
tmux send-keys -t "$SESSION:all-3-servers.1" "ssh $SSH_OPTS -p 2222 ansible@127.0.0.1" C-m

# Split again for Server 3 (Port 2223)
tmux split-window -v -t "$SESSION:all-3-servers"
tmux send-keys -t "$SESSION:all-3-servers.2" "ssh $SSH_OPTS -p 2223 ansible@127.0.0.1" C-m

# Arrange all 3 panes evenly stacked
tmux select-layout -t "$SESSION:all-3-servers" even-vertical

# ------------------------------------------------------------------------------
# WINDOW 1, 2, 3: Full-Screen Individual Server Tabs to Flip Between
# ------------------------------------------------------------------------------
tmux new-window -t "$SESSION" -n "server1-web" "ssh $SSH_OPTS -p 2221 ansible@127.0.0.1"
tmux new-window -t "$SESSION" -n "server2-app" "ssh $SSH_OPTS -p 2222 ansible@127.0.0.1"
tmux new-window -t "$SESSION" -n "server3-db"  "ssh $SSH_OPTS -p 2223 ansible@127.0.0.1"

# Start on Window 0 (All 3 servers view)
tmux select-window -t "$SESSION:all-3-servers"

# Attach your MacBook terminal to the tmux session
tmux attach-session -t "$SESSION"

