ARG ROOT_CONTAINER=rockylinux:8.8.20230518
ARG BASE_CONTAINER=$ROOT_CONTAINER
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter-JSC <jupyter-jsc@fz-juelich.de>"
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

# Install global packages.
USER root

RUN dnf -y update && \
    # Needed for davfs2
    dnf -y install epel-release && \
    dnf -y install bzip2 davfs2 findutils gcc make procps rsync sudo tcl-devel wget && \
    dnf clean all
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
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME

# Download lua and lmod 
RUN mkdir -p /opt/apps/install
RUN wget -O /opt/apps/install/lua-5.1.4.9.tar.bz2 https://sourceforge.net/projects/lmod/files/lua-5.1.4.9.tar.bz2/download
RUN wget -O /opt/apps/install/lmod-8.7.tar.bz2 https://sourceforge.net/projects/lmod/files/Lmod-8.7.tar.bz2/download

# Install lua
COPY --chown=root:root ./install_files/lua /opt/apps/install/lua
RUN /bin/bash /opt/apps/install/lua/install_lua_5.1.4.9.sh
# Install lmod
COPY --chown=root:root ./install_files/lmod /opt/apps/install/lmod
RUN /bin/bash /opt/apps/install/lmod/install_lmod_8.7.sh

WORKDIR /home/$NB_USER
COPY files/bash.bashrc /etc/bash.bashrc
COPY files/mnt.sh /tmp/mnt.sh
COPY files/load_modules.sh /tmp/custom/load_modules.sh
RUN /bin/bash /tmp/mnt.sh && rm /tmp/mnt.sh

USER jovyan
ENTRYPOINT ["/bin/bash", "-l", "-c", "source /tmp/custom/start_jupyter.sh"]