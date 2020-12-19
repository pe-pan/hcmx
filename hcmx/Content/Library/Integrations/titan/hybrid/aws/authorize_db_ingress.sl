########################################################################################################################
#!!
#! @description: Learns the details of the DB instance (its endpoint and port) and makes it accessible from the provided cidrip block.
#!
#! @input instance_arn: DB ARN identifier
#! @input cidrip: CIDRIP block from where to make the DB accessible
#!!#
########################################################################################################################
namespace: Integrations.titan.hybrid.aws
flow:
  name: authorize_db_ingress
  inputs:
    - instance_arn
    - ip_protocol:
        default: tcp
        private: true
    - access_key:
        required: false
    - secret_key:
        required: false
        sensitive: true
    - cidrip
  workflow:
    - describe_instances:
        do:
          io.cloudslang.amazon.aws.rds.instance.describe_instances:
            - access_key: '${access_key}'
            - secret_key: '${secret_key}'
            - region: "${instance_arn.split(':')[3]}"
            - instance_id: '${instance_arn}'
        publish:
          - instances_json
        navigate:
          - FAILURE: on_failure
          - SUCCESS: get_db_endpoint
          - NOT_FOUND: FAILURE
    - describe_vpcs:
        do:
          io.cloudslang.amazon.aws.ec2.vpc.describe_vpcs:
            - access_key: '${access_key}'
            - secret_key: '${secret_key}'
            - region: "${instance_arn.split(':')[3]}"
            - default: 'true'
        publish:
          - vpc_ids
        navigate:
          - FAILURE: on_failure
          - SUCCESS: describe_sgs
    - describe_sgs:
        do:
          io.cloudslang.amazon.aws.ec2.security_group.describe_sgs:
            - access_key: '${access_key}'
            - secret_key: '${secret_key}'
            - region: "${instance_arn.split(':')[3]}"
            - group_name: default
            - vpc_id: '${vpc_ids}'
        publish:
          - sg_ids
        navigate:
          - FAILURE: on_failure
          - SUCCESS: authorize_sg_ingress
    - authorize_sg_ingress:
        do:
          io.cloudslang.amazon.aws.ec2.security_group.authorize_sg_ingress:
            - access_key: '${access_key}'
            - secret_key: '${secret_key}'
            - region: "${instance_arn.split(':')[3]}"
            - sg_id: '${sg_ids}'
            - cidrip: '${cidrip}'
            - ip_protocol: '${ip_protocol}'
            - from_port: '${db_port}'
            - to_port: '${db_port}'
        publish:
          - authorize_result_xml: '${result_xml}'
          - status_code
        navigate:
          - FAILURE: ingress_already_exists
          - SUCCESS: SUCCESS
    - get_db_endpoint:
        do:
          io.cloudslang.base.json.json_path_query:
            - json_object: '${instances_json}'
            - json_path: '$.DescribeDBInstancesResponse.DescribeDBInstancesResult.DBInstances[0].Endpoint.Address'
        publish:
          - db_endpoint: '${return_result[1:-1]}'
        navigate:
          - SUCCESS: get_db_port
          - FAILURE: on_failure
    - get_db_port:
        do:
          io.cloudslang.base.json.json_path_query:
            - json_object: '${instances_json}'
            - json_path: '$.DescribeDBInstancesResponse.DescribeDBInstancesResult.DBInstances[0].Endpoint.Port'
        publish:
          - db_port: '${return_result}'
        navigate:
          - SUCCESS: describe_vpcs
          - FAILURE: on_failure
    - ingress_already_exists:
        do:
          io.cloudslang.base.utils.is_true:
            - bool_value: "${str('already exists' in authorize_result_xml and status_code == '400')}"
        navigate:
          - 'TRUE': SUCCESS
          - 'FALSE': FAILURE
  outputs:
    - db_endpoint: '${db_endpoint}'
    - db_port: '${db_port}'
  results:
    - FAILURE
    - SUCCESS
extensions:
  graph:
    steps:
      describe_instances:
        x: 77
        'y': 72
        navigate:
          66623dc6-24a0-8a2a-b16b-58f833ab78ba:
            targetId: 9b8db313-b052-dcee-fda4-e8df2c71f15b
            port: NOT_FOUND
      describe_vpcs:
        x: 482
        'y': 257
      describe_sgs:
        x: 483
        'y': 457
      authorize_sg_ingress:
        x: 286
        'y': 456
        navigate:
          75b22901-0f69-c3ef-d413-8be303069966:
            targetId: 5740f67b-2ed0-2a74-c006-546c37dded0c
            port: SUCCESS
      get_db_endpoint:
        x: 283
        'y': 72
      get_db_port:
        x: 482
        'y': 73
      ingress_already_exists:
        x: 70
        'y': 458
        navigate:
          d2d3346c-65b9-4449-8c37-78fb9a8ccd7f:
            targetId: 5740f67b-2ed0-2a74-c006-546c37dded0c
            port: 'TRUE'
          3c535407-2501-d230-bd16-5f74bd13cf39:
            targetId: 9b8db313-b052-dcee-fda4-e8df2c71f15b
            port: 'FALSE'
    results:
      FAILURE:
        9b8db313-b052-dcee-fda4-e8df2c71f15b:
          x: 70
          'y': 260
      SUCCESS:
        5740f67b-2ed0-2a74-c006-546c37dded0c:
          x: 282
          'y': 257
