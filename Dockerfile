FROM opensuse/leap:latest

# Refresh repositories and install dependencies + Rclone
RUN zypper refresh && \
    zypper --non-interactive install git curl sudo python3 python3-pip && \
    curl https://rclone.org | bash && \
    zypper clean -a

# Copy the system entrypoint into the image
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Ensure script is executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ComfyUI (8188) and Rclone GUI (5572)
EXPOSE 8188 5572

WORKDIR /root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
