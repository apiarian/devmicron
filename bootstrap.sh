#! /bin/bash

set -euxo pipefail

cat > /etc/ssh/sshd_config.d/server.conf<< EOF
PasswordAuthentication no
PermitRootLogin no
AllowTcpForwarding no
ClientAliveCountMax 2
Compression no
LogLevel VERBOSE
MaxAuthTries 3
MaxSessions 5
X11Forwarding no
EOF

systemctl daemon-reload
systemctl restart sshd

# not sure why it decides to shut down
systemctl restart systemd-journald

dnf install -y \
  ansible \
  git \
  firewalld \
  postfix \
  fail2ban \
  fail2ban-firewalld \
  tmux \
  dnf-automatic \
  chkrootkit
  
systemctl enable --now dnf-automatic-install.timer

systemctl enable firewalld
systemctl start firewalld

systemctl enable postfix
systemctl start postfix

echo 'smtpd_banner = $myhostname ESMTP' >> /etc/postfix/main.cf
systemctl daemon-reload
systemctl restart postfix

systemctl enable fail2ban
systemctl start fail2ban

cat > /etc/fail2ban/jail.d/server.conf<< EOF
[DEFAULT]
bantime = 3600
sender = fail2ban@megamicron.net
destmail = aleksandr
action = %(action_mwl)s

[sshd]
enabled = true
EOF

systemctl daemon-reload
systemctl restart fail2ban

echo "aleksandr:INITIAL_PASSWORD::::/home/aleksandr:/bin/bash" | newusers
usermod -aG wheel aleksandr

mkdir /home/aleksandr/.ssh

cat > /home/aleksandr/.tmux.conf<< \EOF
# remap prefix
unbind C-b
set-option -g prefix C-a
bind-key C-a last-window

# better split commands
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# switch panes with vim-like keys
bind-key j select-pane -D
bind-key k select-pane -U
bind-key h select-pane -L
bind-key l select-pane -R

# don't rename windows automatically
set-option -g allow-rename off

# bigger history
set-option -g history-limit 50000

# vim keybindings in copy mode
set-option -g mode-keys vi

# make the status bar pretty
set -g status-justify centre
set -g status-style "fg=white bg=black bright"
set -g status-left-length 40
set -g status-left "#{prefix_highlight} [#S] #[fg=blue]#H"
set -g status-right-length 80
set -g status-right '#[fg=white]%a %H:%M #[fg=blue]%m-%d #[fg=red]#(date -u "+%%H:%%M(%%d)UTC")'
set -g status-interval 10

set-window-option -g window-status-style "fg=white bg=black dim"
set-window-option -g window-status-current-style "fg=red bg=black bright"

set -g mouse on

# make the current pane stand out more
set -g pane-border-style "fg=white bg=black"
set -g pane-active-border-style "fg=white bg=green"

set -s escape-time 0

setw -g aggressive-resize on

setw -g monitor-activity on
set -g visual-activity on

# re-number windows when one is closed
set -g renumber-windows on

# number things starting from 1
set -g base-index 1
set -g pane-base-index 1

# focus events enabled for terminals that support them
set -g focus-events on

# clear scrollback
bind C-k clear-history

# Smart pane switching with awareness of Vim splits.
# See: https://github.com/christoomey/vim-tmux-navigator
is_vim="ps -o state= -o comm= -t '#{pane_tty}' | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|n?vim?x?)(diff)?$'"

bind-key -n C-h if-shell "$is_vim" "send-keys C-h"  "select-pane -L"
bind-key -n C-j if-shell "$is_vim" "send-keys C-j"  "select-pane -D"
bind-key -n C-k if-shell "$is_vim" "send-keys C-k"  "select-pane -U"
bind-key -n C-l if-shell "$is_vim" "send-keys C-l"  "select-pane -R"
bind-key -n C-\\ if-shell "$is_vim" "send-keys C-\\\\" "select-pane -l"
bind-key -T copy-mode-vi C-h select-pane -L
bind-key -T copy-mode-vi C-j select-pane -D
bind-key -T copy-mode-vi C-k select-pane -U
bind-key -T copy-mode-vi C-l select-pane -R
bind-key -T copy-mode-vi C-\\ select-pane -l

# plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-prefix-highlight'
set -g @plugin 'tmux-plugins/tmux-open'
set -g @plugin 'tmux-plugins/tmux-urlview'

run '~/.tmux/plugins/tpm/tpm'

# git clone https://github.com/tmux-plugins/tpm.git /home/aleksandr/.tmux/plugins/tpm
# then to press prefix-I to install plugins
EOF

cp /root/.ssh/authorized_keys /home/aleksandr/.ssh/authorized_keys
chown -R aleksandr:aleksandr /home/aleksandr
chmod 0600 /home/aleksandr/.ssh/authorized_keys
restorecon -FRvv /home/aleksandr/.ssh

dnf upgrade -y
reboot