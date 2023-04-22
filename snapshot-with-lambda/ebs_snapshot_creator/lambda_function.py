import boto3
import datetime
import os

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')

    # retention days of snapshot
    retention_days = os.environ.get('RETENTION_DAYS', 7)
    # define tags
    snapshot_tags = {
        'Environment': os.environ.get('ENVIRONMENT_TAG', 'prod'),
        'Application': os.environ.get('APPLICATION_TAG', 'myapp'),
        'Owner': os.environ.get("OWNER_TAG", "Anson")
    }

    volumes = ec2.describe_volumes()['Volumes']

    for volume in volumes:
        volume_id = volume['VolumeId']
        snapshot_description = f"Snapshot of volume {volume_id} taken at {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC"
        snapshot_tags['VolumeId'] = volume_id
        snapshot_tags['Name'] = f"{volume_id}-snapshot-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

        snapshot = ec2.create_snapshot(
            VolumeId=volume_id,
            Description=snapshot_description,
            TagSpecifications=[
                {
                    'ResourceType': 'snapshot',
                    'Tags': [
                        {
                            'Key': tag_key,
                            'Value': tag_value
                        } for tag_key, tag_value in snapshot_tags.items()
                    ]
                }
            ]
        )

        ec2.create_tags(
            Resources=[snapshot['SnapshotId']],
            Tags=[
                {
                    'Key': tag_key,
                    'Value': tag_value
                } for tag_key, tag_value in snapshot_tags.items()
            ]
        )

        snapshot_date = snapshot['StartTime'].replace(tzinfo=None)
        snapshot_age = (datetime.datetime.utcnow() - snapshot_date).days

        if snapshot_age >= retention_days:
            ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])