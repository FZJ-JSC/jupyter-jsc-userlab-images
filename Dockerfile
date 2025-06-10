ARG ROOT_CONTAINER=rockylinux/rockylinux:9.5.20241118-ubi
ARG BASE_CONTAINER=$ROOT_CONTAINER
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter-JSC <ds-support@fz-juelich.de>"
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Install global packages.
USER root

COPY ./files/dnf_packages.txt /tmp/dnf_packages.txt
RUN dnf -yq update && \
    dnf -yq install epel-release findutils && \
    cat /tmp/dnf_packages.txt | xargs dnf install -yq && \
    dnf clean all && rm /tmp/dnf_packages.txt

# Download and install curlftpfs
RUN mkdir -p /opt/apps/install
COPY --chown=root:root ./install_files/curlftpfs /opt/apps/install/curlftpfs
RUN /bin/bash /opt/apps/install/curlftpfs/install_curlftpfs_0.9.2.sh

# Download and install davfs2
COPY --chown=root:root ./install_files/davfs2-1.7.0-7.el9.x86_64.rpm /tmp/davfs2-1.7.0-7.el9.x86_64.rpm
RUN rpm -ivh /tmp/davfs2-1.7.0-7.el9.x86_64.rpm && rm /tmp/davfs2-1.7.0-7.el9.x86_64.rpm

# Download and install Node.js 20.x
RUN wget -O /tmp/nodejs.sh https://rpm.nodesource.com/setup_20.x && bash /tmp/nodejs.sh && dnf install nodejs -y && rm /tmp/nodejs.sh

# Copy a script that we will use to correct permissions after running certain commands
COPY ./files/fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Create NB_USER with name jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER -G davfs2 && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME

# RUN mkdir -p /opt/apps/install
COPY --chown=root:root ./install_files/lua-5.1.4.9.tar.bz2 /opt/apps/install/lua-5.1.4.9.tar.bz2
COPY --chown=root:root ./install_files/lmod-8.7.tar.bz2 /opt/apps/install/lmod-8.7.tar.bz2

# Install lua
COPY --chown=root:root ./install_files/lua /opt/apps/install/lua
RUN /bin/bash /opt/apps/install/lua/install_lua_5.1.4.9.sh
# Install lmod
COPY --chown=root:root ./install_files/lmod /opt/apps/install/lmod
RUN /bin/bash /opt/apps/install/lmod/install_lmod_8.7.sh

COPY ./files/bash.bashrc /etc/bash.bashrc
COPY ./files/start-singleuser.sh /usr/local/bin/start-singleuser.sh
RUN fix-permissions /usr/local/bin
RUN chmod +x /usr/local/bin/start-singleuser.sh

USER $NB_USER
WORKDIR /home/$NB_USER
CMD ["start-singleuser.sh"]
