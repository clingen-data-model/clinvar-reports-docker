#!/bin/sh
# Runs all of the ClinVar reports.
# Mounts, writes to, and unmounts a GCS Bucket.

#
# This is the google bucket that is mounted
# via gcsfuse to the directory where the reports are
# written. Defaults to clinvar-reports.
#
GS_BUCKET=${1:-clinvar-reports}

#
# Key file for writing to the bucket.
# Defaults to /storage-bucket-keyfile.json
#
KEY_FILE=${2:-/storage-bucket-keyfile.json}

#
# PubSub Delete Topic
#
PUB_SUB_TOPIC=${3:-delete-instance-event}

#
# Zero Star Reports
#
zero_star()
{
    BASE=/home/clinvar/clinvar-reports
    DIR=$BASE/ClinVarZeroStarReports
    /usr/local/bin/gcsfuse --key-file $KEY_FILE $GS_BUCKET $DIR
    echo "Starting ZeroStar Reports at " `date` >>  $DIR/log.txt
    python3 ./ClinVarExcelReports.py ZeroStar >> $DIR/log.txt 2>&1
    echo "Completed ZeroStar Reports at " `date` >>  $DIR/log.txt
    fusermount -u $DIR
}

#
# One Star Reports
#
one_star()
{
    BASE=/home/clinvar/clinvar-reports
    DIR=$BASE/ClinVarOneStarReports
    /usr/local/bin/gcsfuse --key-file $KEY_FILE $GS_BUCKET $DIR
    echo "Starting OneStar Reports at " `date` >>  $DIR/log.txt
    python3 ./ClinVarExcelReports.py OneStar >> $DIR/log.txt 2>&1
    echo "Completed OneStar Reports at " `date` >>  $DIR/log.txt
    fusermount -u $DIR
}

#
# Expert Panel Reports
#
ep_reports()
{
    EP_BASE=/home/clinvar/clinvar-ep-reports
    DIR=$EP_BASE/ClinVarExpertPanelReports
    /usr/local/bin/gcsfuse --key-file $KEY_FILE $GS_BUCKET $DIR
    echo "Starting EP Reports at " `date` >> $DIR/log.txt
    cd $EP_BASE
    python3 ./EPReports.py >> $DIR/log.txt 2>&1
    echo "Completed EP Reports at " `date` >>  $DIR/log.txt
    fusermount -u $DIR
}

#
# Genome Connect Reports
#
gc_reports()
{
    GC_BASE=/home/clinvar/genomeconnect-report
    DIR=$GC_BASE/ClinVarGCReports
    /usr/local/bin/gcsfuse --key-file $KEY_FILE $GS_BUCKET $DIR
    echo "Starting GC Reports at " `date` >>  $DIR/log.txt
    cd $GC_BASE
    python3 ./ClinVarGCReports.py >> $DIR/log.txt 2>&1
    echo "Completed GC Reports at " `date` >>  $DIR/log.txt
    fusermount -u $DIR
}

#
# Publish a message to take down the VM
#
# TODO - Project Dependency
#
publish_takedown_to_topic()
{
    echo "Starting Publish to topic $PUB_SUB_TOPIC at " `date` >> /publish_log.txt
    MESSAGE="{ 'project': 'clingen-dev', 'zone': 'us-east1-b', 'image': 'projects/clingen-dev/global/instanceTemplates/clinvar-reports-all', 'name': 'clinvar-reports-all' }"
    # B64_MESSAGE=`echo $MESSAGE | base64` 
    # final message should be in the form
    # {"data": "eyAncHJvamVjdCc6ICdjbGluZ2VuLWRldicsICd6b25lJzogJ3VzLWVhc3QxLWInLCAnaW1hZ2UnOiAncHJvamVjdHMvY2xpbmdlbi1kZXYvZ2xvYmFsL2luc3RhbmNlVGVtcGxhdGVzL2NsaW52YXItcmVwb3J0cy1hbGwnLCAnbmFtZSc6ICdjbGludmFyLXJlcG9ydHMtYWxsJyB9Cg=="}
    # This can be cut and paste when testing cloud functions
    # gcloud pubsub topics publish $PUB_SUB_TOPIC --message "{\"data\":\"$B64_MESSAGE\"}"
    gcloud pubsub topics publish $PUB_SUB_TOPIC --message "$MESSAGE" >> /publish_log.txt 2>&1
    echo "Finished Publish to topic $PUB_SUB_TOPIC at " `date` >>  /publish_log.txt
}

#
# Send email
#
send_email()
{
    echo "Testing e-mail to toneill@broadinstitute.com from within a GCP compute engine with container." | \
	mutt -x -s "ClinVar Reports" -- toneill@broadinstitute.org
} 

#
# Commit Hari Kari
#
hari_kari()
{
    gcloud compute instances delete clinvar-reporting-all --zone us-east4-c
}

copy_run_log()
{
    LOGFILE=/run_log.txt
    PUBLOGFILE=/publish_log.txt
    if [ -f $LOGFILE -o -f $PUBLOGFILE ]; then
	MNT=/mnt/log
        mkdir $MNT
	/usr/local/bin/gcsfuse --key-file $KEY_FILE $GS_BUCKET $MNT
	cp $LOGFILE $MNT
	cp $PUBLOGFILE $MNT
	fusermount -u $MNT
    fi
}
#
# Main
#
zero_star
one_star
ep_reports
gc_reports
#send_email
# sleep 60
publish_takedown_to_topic
# hari_kari
copy_run_log
