FROM yanwk/comfyui-boot:cu128-slim

# Refresh repositories and install dependencies + Rclone
RUN zypper refresh && \
    zypper --non-interactive install git curl sudo python3 python3-pip && \
    zypper clean -a

# Copy the system entrypoint into the image
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

# Ensure script is executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ComfyUI (8188) and Rclone GUI (5572)
EXPOSE 8188 5572

WORKDIR /root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
