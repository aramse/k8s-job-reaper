FROM centos

# install kubectl
RUN KUBECTL_VERSION=1.15.3 && curl -vo kubectl http://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/

# install other dependencies
RUN yum install -y epel-release && yum clean all
RUN yum install -y jq && yum clean all

# copy collector to container
COPY reap.sh ./
RUN chmod +x reap.sh

CMD ./reap.sh
