import googleapiclient.discovery
import base64
import argparse
import time


def create_pubsub(data, context):
    print("CREATE_PUBSUB - Start")
    print("CREATE_PUBSUB - Received Data", data)
    compute, project, zone, name, image = init(data)
    operation = create_instance(compute, project, zone, name, image)
    wait_for_operation(compute, project, zone, operation['name'])
    print("CREATE_PUBSUB - End")


def delete_pubsub(data, context):
    print("DELETE_PUBSUB - Start")
    print("DELETE_PUBSUB - Received Data", data)
    compute, project, zone, name, image = init(data)
    operation = delete_instance(compute, project, zone, name)
    wait_for_operation(compute, project, zone, operation['name'])
    print("DELETE_PUBSUB - End")


def init(data):
    print("INIT - Start - received data: ", data)
    if 'data' in data:
        msg_str = base64.b64decode(data['data']).decode('utf-8')
        msg_dict = eval(msg_str)
        print("AFTER EVAL msg_dict is:", type(msg_dict), msg_dict)
        project = msg_dict['project']
        zone = msg_dict['zone']
        name = msg_dict['name']
        image = msg_dict['image']
        print("INIT - Project: " + project + " Zone: " + zone + " Name: " + name + " Image: " + image)
    compute = googleapiclient.discovery.build('compute', 'v1')
    print("INIT - Leaving")

    return compute, project, zone, name, image


def create_instance(compute, project, zone, name, instance_template):
    print("CREATE_INSTANCE - Start")

    # Get the latest Debian Jessie image.
    # image_response = compute.images().getFromFamily(
    #    project='debian-cloud', family='debian-9').execute()
    # source_disk_image = image_response['selfLink']

    # Configure the machine
    # machine_type = "zones/%s/machineTypes/n1-standard-1" % zone

    # TODO - Project dependencies
    # TODO - Zone dependencies
    # TODO - Naming dependencies
    #
    # This config is from a running VM created from an instance template
    #
    config = {
        "name": "clinvar-reports-all",
        "zone": "projects/clingen-dev/zones/us-east1-b",
        "machineType": "projects/clingen-dev/zones/us-east1-b/machineTypes/n1-standard-1",
        "displayDevice": {
          "enableDisplay": 'false'
        },
        "metadata": {
        "kind": "compute#metadata",
        "items": [
            {
                "key": "gce-container-declaration",
                "value": "spec:\n  containers:\n    - name: clinvar-reports-all\n      image: 'gcr.io/clingen-dev/clinvar-reports-all:latest'\n      securityContext:\n        privileged: true\n      stdin: false\n      tty: false\n  restartPolicy: Never\n\n# This container declaration format is not public API and may change without notice. Please\n# use gcloud command-line tool or Google Cloud Console to run Containers on Google Compute Engine."
            },
            {
                "key": "google-logging-enabled",
                "value": "true"
            }
        ]
        },
        "tags": {
            "items": []
        },
        # Specify the boot disk and the image to use as a source.
        "disks": [
        {
           "kind": "compute#attachedDisk",
            "type": "PERSISTENT",
            "boot": 'true',
            "mode": "READ_WRITE",
            "autoDelete": 'true',
            "deviceName": "clinvar-reports-all",
            "initializeParams": {
              "sourceImage": "projects/cos-cloud/global/images/cos-stable-74-11895-86-0",
              "diskType": "projects/clingen-dev/zones/us-east1-b/diskTypes/pd-standard",
              "diskSizeGb": "10"
          }
        }
      ],

        # Specify a network interface with NAT to access the public
        # internet.
        'networkInterfaces': [{
            'network': 'global/networks/default',
            'accessConfigs': [
                {'type': 'ONE_TO_ONE_NAT', 'name': 'External NAT'}
            ]
        }],

        # Allow the instance to access cloud storage and logging.
        "serviceAccounts": [
        {
       "email": "522856288592-compute@developer.gserviceaccount.com",
        "scopes": [
          "https://www.googleapis.com/auth/devstorage.read_only",
          "https://www.googleapis.com/auth/logging.write",
          "https://www.googleapis.com/auth/monitoring.write",
          "https://www.googleapis.com/auth/servicecontrol",
          "https://www.googleapis.com/auth/service.management.readonly",
          "https://www.googleapis.com/auth/trace.append",
          "https://www.googleapis.com/auth/cloud-platform"
          ]
        }
      ]
    }
    print("CREATE_INSTANCE - End")

    return compute.instances().insert(
        project=project,
        zone=zone,
        body=config,
        sourceInstanceTemplate=instance_template).execute()


def delete_instance(compute, project, zone, name):
    print("DELETE_INSTANCE - Start/End")

    return compute.instances().delete(
        project=project,
        zone=zone,
        instance=name).execute()


def wait_for_operation(compute, project, zone, operation):
    print('Waiting for operation to finish...')
    while True:
        result = compute.zoneOperations().get(
            project=project,
            zone=zone,
            operation=operation).execute()

        if result['status'] == 'DONE':
            print("done.")
            if 'error' in result:
                raise Exception(result['error'])
            return result

        time.sleep(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--data')

    args = parser.parse_args()

    create_pubsub(dict(data=args.data), None)
    #delete_pubsub(dict(data=args.data), None)
