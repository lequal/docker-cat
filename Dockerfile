FROM sonarqube:7.9.3-community AS framac

## ====================== INSTALL FRAMA-C =============================

USER root
WORKDIR /tmp/framac

RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update -y \
    && apt-get install -y \
       git \
       ocaml \
       ocaml-native-compilers \
       liblablgtk2-ocaml-dev \
       liblablgtksourceview2-ocaml-dev \
       libocamlgraph-ocaml-dev \
       menhir \
       why3 \
       libyojson-ocaml-dev \
       libocamlgraph-ocaml-dev \
       libzarith-ocaml-dev \
       build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --single-branch https://github.com/Frama-C/Frama-C-snapshot.git . \
    && git checkout -b tags/20.0 \
    && ./configure \
    && make \
    && make install


## ====================== BUILD FINAL IMAGE ===================================

FROM sonarqube:7.9.3-community
ENV SONAR_RUNNER_HOME=/opt/sonar-scanner
ENV PATH $PATH:/opt/sonar-scanner
USER root
RUN mkdir /opt/sonar
COPY ./conf /tmp/conf


## ====================== DOWNLOAD DEPENDENCIES ===============================

# Download SonarQube plugins
ADD https://github.com/checkstyle/sonar-checkstyle/releases/download/4.21/checkstyle-sonar-plugin-4.21.jar \
    https://github.com/galexandre/sonar-cobertura/releases/download/1.9.1/sonar-cobertura-plugin-1.9.1.jar \
    https://github.com/SonarOpenCommunity/sonar-cxx/releases/download/cxx-1.3.1/sonar-cxx-plugin-1.3.1.1807.jar \
    https://github.com/spotbugs/sonar-findbugs/releases/download/3.11.0/sonar-findbugs-plugin-3.11.0.jar \
    https://github.com/willemsrb/sonar-rci-plugin/releases/download/sonar-rci-plugin-1.0.1/sonar-rci-plugin-1.0.1.jar \
    https://binaries.sonarsource.com/Distribution/sonar-flex-plugin/sonar-flex-plugin-2.5.1.1831.jar \
    https://github.com/lequal/sonar-cnes-cxx-plugin/releases/download/v1.1.0/sonar-cnes-cxx-plugin-1.1.jar \
    https://github.com/lequal/sonar-cnes-export-plugin/releases/download/v1.2.0/sonar-cnes-export-plugin-1.2.jar \
    https://github.com/lequal/sonar-cnes-python-plugin/releases/download/1.3/sonar-cnes-python-plugin-1.3.jar \
    https://github.com/lequal/sonar-icode-cnes-plugin/releases/download/2.0.2/sonar-icode-cnes-plugin-2.0.2.jar \
    https://github.com/lequal/sonar-frama-c-plugin/releases/download/V2.1.1/sonar-frama-c-plugin-2.1.1.jar \
    https://github.com/lequal/sonar-cnes-scan-plugin/releases/download/1.5.0/sonar-cnes-scan-plugin-1.5.jar \
    https://github.com/lequal/sonar-cnes-report/releases/download/3.2.2/sonar-cnes-report-3.2.2.jar \
    https://github.com/jensgerdes/sonar-pmd/releases/download/3.2.1/sonar-pmd-plugin-3.2.1.jar \
    /opt/sonarqube/extensions/plugins/


# Download software
ADD https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/rough-auditing-tool-for-security/rats-2.4.tgz \
    http://downloads.sourceforge.net/project/expat/expat/2.0.1/expat-2.0.1.tar.gz \
    https://github.com/lequal/i-CodeCNES/releases/download/v4.1.0/icode-4.1.0.zip \
    https://netix.dl.sourceforge.net/project/cppcheck/cppcheck/1.90/cppcheck-1.90.tar.gz \
    /tmp/


# Sonar Scanner installation
ADD https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.2.0.1873-linux.zip \
    /tmp/scanners/


# CNES Pylint extension
ENV PYTHONPATH $PYTHONPATH:/opt/python/cnes-pylint-extension-5.0.0/checkers/
ADD https://github.com/lequal/cnes-pylint-extension/archive/v5.0.0.tar.gz \
    /tmp/python/


## ====================== INSTALL DEPENDENCIES ===============================

## Install Frama-C from previous stage
COPY --from=framac /usr/local/ /usr/local/
ENV PATH /usr/local/bin:${PATH}

ENV HOME /home/sonarqube
RUN echo 'deb http://ftp.fr.debian.org/debian/ bullseye main contrib non-free' >> /etc/apt/sources.list \
    && apt-get update -y \
    && apt-get install -y \
       unzip \
       python3 \
       python3-pip \
       vera\+\+=1.2.1-* \
       shellcheck=0.7.1-* \
       gcc=4:9.2.1-* \
       make=4.2.1-* \
       g\+\+ \
       libpcre3 \
       libpcre3-dev \
       libfindlib-ocaml \
       libocamlgraph-ocaml-dev \
       libzarith-ocaml \
       libyojson-ocaml \
       jq \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /home/sonarqube \
    ## Install i-Code CNES
    && unzip /tmp/icode-4.1.0.zip -d /tmp \
    && chmod +x /tmp/icode/icode \
    && mv /tmp/icode/* /usr/bin \
    && rm -r /tmp/icode \
    && rm /tmp/icode-4.1.0.zip \
    ## Install Sonar Scanner
    && unzip /tmp/scanners/sonar-scanner-cli-4.2.0.1873-linux.zip -d /opt/ \
    && mv /opt/sonar-scanner-4.2.0.1873-linux /opt/sonar-scanner \
    && rm -rf /tmp/scanners \
    ## Python, Pylint & CNES Pylint setup
    && mkdir /opt/python \
    && tar -xvzf /tmp/python/v5.0.0.tar.gz -C /opt/python \
    && rm -rf /tmp/python \
    && pip install \
       setuptools==44.0.0 \
       setuptools-scm==3.5.0 \
       pytest-runner==5.2 \
       wrapt==1.12.1 \
       six==1.14.0 \
       lazy-object-proxy==1.4.3 \
       mccabe==0.6.1 \
       isort==4.3.21 \
       typed-ast==1.4.1 \
       astroid==2.4.0 \
       pylint==2.5.0 \
    && pip cache purge \
    ## C and C++ tools installation
    && cd /tmp \
    && tar -xvzf expat-2.0.1.tar.gz \
    && cd expat-2.0.1 \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -rf ./expat-2.0.1.tar.gz ./expat-2.0.1 \
    && tar -xzvf rats-2.4.tgz \
    && cd rats-2.4 \
    && ./configure --with-expat-lib=/usr/local/lib \
    && make \
    && make install \
    && ./rats \
    && cd .. \
    && rm -rf ./rats-2.4.tgz ./rats-2.4 \
    && tar -zxvf cppcheck-1.90.tar.gz \
    && cd cppcheck-1.90/ \
    && make install MATCHCOMPILER="yes" FILESDIR="/usr/share/cppcheck" HAVE_RULES="yes" CXXFLAGS="-O2 -DNDEBUG -Wall -Wno-sign-compare -Wno-unused-function -Wno-deprecated-declarations" \
    && cd .. \
    && rm -rf ./cppcheck-1.90.tar.gz ./cppcheck-1.90/ \
    && chown sonarqube:sonarqube -R /opt \
    && chown sonarqube:sonarqube -R /home \
    && apt-get autoremove -y \
       make \
       g\+\+ \
       libpcre3-dev


## ====================== CONFIGURATION ===============================

# Entry point files
COPY ./configure-cat.bash /tmp/
COPY ./init.bash /tmp/

# Make sonarqube owner of it's installation directories
RUN ls -lrta /opt/ \
    && chmod 750 /tmp/init.bash \
    && chown sonarqube:sonarqube -R /tmp/conf \
    && mkdir -p /opt/sonar/extensions/ \
    && ln -s /opt/sonarqube/extensions/plugins /opt/sonar/extensions/plugins \
    && mkdir -p /opt/sonarqube/frama-c/ \
    && ln -s /usr/local/bin/frama-c /opt/sonarqube/frama-c/frama-c \
###### Disable telemetry
    && sed -i 's/#sonar\.telemetry\.enable=true/sonar\.telemetry\.enable=false/' /opt/sonarqube/conf/sonar.properties \
###### Set default report path for Cppcheck
    && echo 'sonar.cxx.cppcheck.reportPath=cppcheck-report.xml' >> /opt/sonar-scanner/conf/sonar-scanner.properties \
###### Set default report path for Vera++
    && echo 'sonar.cxx.vera.reportPath=vera-report.xml' >> /opt/sonar-scanner/conf/sonar-scanner.properties \
###### Set default report path for RATS
    && echo 'sonar.cxx.rats.reportPath=rats-report.xml' >> /opt/sonar-scanner/conf/sonar-scanner.properties \
###### Solve following error: https://github.com/lequal/docker-cat/issues/30
    && chmod -R 777 /opt/sonarqube/temp


## ====================== STARTING ===============================

WORKDIR $SONARQUBE_HOME
ENTRYPOINT ["/tmp/init.bash"]
