ARG ROOT_CONTAINER=rockylinux:8.8.20230518
ARG BASE_CONTAINER=$ROOT_CONTAINER
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter-JSC <jupyter-jsc@fz-juelich.de>"
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Install global packages.
USER root

COPY files/dnf_packages.txt /tmp/dnf_packages.txt
RUN dnf -yq update && \
    dnf -yq install epel-release findutils && \
    cat /tmp/dnf_packages.txt | xargs dnf install -yq && \
    dnf clean all && rm /tmp/dnf_packages.txt

# Install python packages
COPY files/pip_packages.txt /tmp/pip_packages.txt
RUN pip install -r /tmp/pip_packages.txt

# Download and install curlftpfs
RUN mkdir -p /opt/apps/install
COPY --chown=root:root ./install_files/curlftpfs /opt/apps/install/curlftpfs
RUN wget -O /opt/apps/install/curlftpfs-0.9.2.tar.gz https://sourceforge.net/projects/curlftpfs/files/curlftpfs/0.9.2/curlftpfs-0.9.2.tar.gz/download && \
    /bin/bash /opt/apps/install/curlftpfs/install_curlftpfs_0.9.2.sh

# Copy a script that we will use to correct permissions after running certain commands
COPY files/fix-permissions /usr/local/bin/fix-permissions
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

# Download lua and lmod 
# RUN mkdir -p /opt/apps/install
RUN wget -O /opt/apps/install/lua-5.1.4.9.tar.bz2 https://sourceforge.net/projects/lmod/files/lua-5.1.4.9.tar.bz2/download
RUN wget -O /opt/apps/install/lmod-8.7.tar.bz2 https://sourceforge.net/projects/lmod/files/Lmod-8.7.tar.bz2/download

# Install lua
COPY --chown=root:root ./install_files/lua /opt/apps/install/lua
RUN /bin/bash /opt/apps/install/lua/install_lua_5.1.4.9.sh
# Install lmod
COPY --chown=root:root ./install_files/lmod /opt/apps/install/lmod
RUN /bin/bash /opt/apps/install/lmod/install_lmod_8.7.sh

COPY files/bash.bashrc /etc/bash.bashrc
COPY files/mnt.sh /tmp/mnt.sh
COPY files/start_jupyter.sh /tmp/custom/start_jupyter.sh
RUN /bin/bash /tmp/mnt.sh && rm /tmp/mnt.sh && fix-permissions /tmp/custom

USER $NB_USER
WORKDIR /home/$NB_USER
ENTRYPOINT ["/bin/bash", "/tmp/custom/start_jupyter.sh"]
