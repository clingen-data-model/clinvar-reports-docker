FROM golang:1.15-alpine
RUN apk add --no-cache git
ENV GOPATH /go
RUN go get -u github.com/googlecloudplatform/gcsfuse

FROM docker
LABEL maintainer="toneill@broadinstitute.org"
LABEL name="Clinvar Reporting and Mutt Mailer"
USER root
RUN apk add --update \
    postfix \
    cyrus-sasl-gssapiv2 \
    cyrus-sasl-login \
    mutt \
    git \
    ca-certificates \
    curl \
    which \
    bash \
    gcc \
    python3 \
    python3-dev \
    py3-pip \
    musl-dev \
    libffi-dev \
    openssl-dev \
    fuse && rm -rf /tmp/*

COPY --from=0 /go/bin/gcsfuse /usr/local/bin

# TODO: NOT SURE THAT THIS IS DOING ANYTHING
RUN postfix start

# Crete User
RUN addgroup clinvar
RUN adduser -h /home/clinvar -s /bin/sh -G clinvar -g "Clinvar Report Generator" -D clinvar

# Install Python packages
RUN pip install --upgrade pip
RUN pip install xlsxwriter
RUN pip install xlrd==1.2.0
RUN pip install --upgrade google-cloud-storage

###### KEY FILE SECTION #########
#
# TODO - Dependency on project specific service account keyfile json
#
# Before building, buiding this docker image be sure to update this line! 
COPY <your project key file> /storage-bucket-keyfile.json
COPY run.sh /run.sh
RUN chmod +x /run.sh
###### KEY FILE SECTION #########

## gcloud setup
RUN curl -sSL https://sdk.cloud.google.com | bash
ENV PATH $PATH:/root/google-cloud-sdk/bin
RUN gcloud auth activate-service-account --key-file /storage-bucket-keyfile.json

#
# TODO - Dependency on project
#
RUN gcloud config set project clingen-dev

WORKDIR /home/clinvar

# muttrc has toneill@braodinstitute.org specific email settings
# COPY ./muttrc /home/clinvar/.muttrc
# COPY ./muttrc /.muttrc

# clone the report generation code
# Base image contains all of the reports code so that
# Run image just changes workdir to code dir potentially
# ZeroStar reports mountpoint: clinvar-reports/ClinVarZeroStarReports
# OneStar reports mountpoint:  clinvar-reports/ClinVarOneStarReports
RUN git clone https://github.com/clingen-data-model/clinvar-reports

# EP Reports mountpoint: clinvar-ep-reports/ClinVarExpertPanelReports
RUN git clone https://github.com/clingen-data-model/clinvar-ep-reports

# Genomeconnect-report mountpoint: genomeconnect-report/ClinVarGCReports
RUN git clone https://github.com/clingen-data-model/genomeconnect-report

# RUN git clone https://github.com/clingen-data-model/clinvar-report-mailers

# These are the attachements and the e-mail files
# Perhaps this needs to be level B
# COPY ./*.pdf ./*.xlsx /home/clinvar/clinvar-reports/

RUN mkdir /home/clinvar/clinvar-reports/ClinVarZeroStarReports
RUN mkdir /home/clinvar/clinvar-reports/ClinVarOneStarReports
RUN mkdir /home/clinvar/clinvar-ep-reports/ClinVarExpertPanelReports
RUN mkdir /home/clinvar/genomeconnect-report/ClinVarGCReports

# Set permissions to clinvar
#RUN chown -R clinvar.clinvar /home/clinvar/
#USER clinvar

WORKDIR /home/clinvar/clinvar-reports
CMD [ "/bin/sh", "-c", "/run.sh clinvar-reports >> /run_log.txt 2>&1"]
