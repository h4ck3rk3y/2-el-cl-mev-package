eth_network_module = import_module("github.com/kurtosis-tech/eth-network-package/main.star")
genesis_constants = import_module("github.com/kurtosis-tech/eth-network-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star")

parse_input = import_module("github.com/kurtosis-tech/eth2-package/src/package_io/parse_input.star")
mev_boost_launcher_module = import_module("github.com/kurtosis-tech/eth2-package/src/mev_boost/mev_boost_launcher.star")
mev_relay_launcher_module = import_module("github.com/kurtosis-tech/eth2-package/src/mev_relay/mev_relay_launcher.star")
transaction_spammer = import_module("github.com/kurtosis-tech/eth2-package/src/transaction_spammer/transaction_spammer.star")

mev_flood_module = import_module("github.com/kurtosis-tech/eth2-package/src/mev_flood/mev_flood_launcher.star")

MEV_BOOST_SHOULD_CHECK_RELAY = True
HTTP_PORT_ID_FOR_FACT = "http"

def run(plan):
    params = {
        "participants": [
        {
            "el_client_type": "geth",
            "el_client_image": "",
            "el_client_log_level": "",
            "cl_client_type": "lighthouse",
            "cl_client_image": "",
            "cl_client_log_level": "",
            "beacon_extra_params": [],
            "el_extra_params": [],
            "validator_extra_params": [],
            "builder_network_params": None,
            "count": 2
        }
        ],
        "network_params": {
        "preregistered_validator_keys_mnemonic": "giant issue aisle success illegal bike spike question tent bar rely arctic volcano long crawl hungry vocal artwork sniff fantasy very lucky have athlete",
        "num_validator_keys_per_node": 64,
        "network_id": "3151908",
        "deposit_contract_address": "0x4242424242424242424242424242424242424242",
        "seconds_per_slot": 12,
        "genesis_delay": 120,
        "capella_fork_epoch": 5,
        "deneb_fork_epoch": 500
        },
        "global_client_log_level": "info",
        "mev_type": "full"
    }

    args_with_right_defaults, args_with_defaults_dict = parse_input.parse_input(params)

    num_participants = len(args_with_right_defaults.participants)
    network_params = args_with_right_defaults.network_params
    mev_params = args_with_right_defaults.mev_params

    all_participants, cl_genesis_timestamp, genesis_validators_root = eth_network_module.run(plan, args_with_defaults_dict)

    all_el_client_contexts = []
    all_cl_client_contexts = []
    for participant in all_participants:
        all_el_client_contexts.append(participant.el_client_context)
        all_cl_client_contexts.append(participant.cl_client_context)
    mev_endpoints = []


    el_uri = "http://{0}:{1}".format(all_el_client_contexts[0].ip_addr, all_el_client_contexts[0].rpc_port_num)
    builder_uri = "http://{0}:{1}".format(all_el_client_contexts[-1].ip_addr, all_el_client_contexts[-1].rpc_port_num)
    beacon_uri = ["http://{0}:{1}".format(context.ip_addr, context.http_port_num) for context in all_cl_client_contexts][-1]
    beacon_uris = beacon_uri
    first_cl_client = all_cl_client_contexts[0]
    first_client_beacon_name = first_cl_client.beacon_service_name
    mev_flood_module.launch_mev_flood(plan, mev_params.mev_flood_image, el_uri)

    epoch_recipe = GetHttpRequestRecipe(
        endpoint = "/eth/v1/beacon/blocks/head",
        port_id = HTTP_PORT_ID_FOR_FACT,
        extract = {
            "epoch": ".data.message.body.attestations[0].data.target.epoch"
        }
    )
    plan.wait(recipe = epoch_recipe, field = "extract.epoch", assertion = ">=", target_value = str(network_params.capella_fork_epoch), timeout = "20m", service_name = first_client_beacon_name)
    plan.print("epoch 2 reached, can begin mev stuff")

    endpoint = mev_relay_launcher_module.launch_mev_relay(plan, mev_params, network_params.network_id, beacon_uris, genesis_validators_root, builder_uri)
    mev_flood_module.spam_in_background(plan, el_uri, mev_params.mev_flood_extra_args)
    mev_endpoints.append(endpoint)

    all_mevboost_contexts = []
    for index, participant in enumerate(args_with_right_defaults.participants):
        mev_boost_launcher = mev_boost_launcher_module.new_mev_boost_launcher(MEV_BOOST_SHOULD_CHECK_RELAY, mev_endpoints)
        mev_boost_service_name = "{0}{1}".format(parse_input.MEV_BOOST_SERVICE_NAME_PREFIX, index)
        mev_boost_context = mev_boost_launcher_module.launch(plan, mev_boost_launcher, mev_boost_service_name, network_params.network_id)
        all_mevboost_contexts.append(mev_boost_context)

    transaction_spammer.launch_transaction_spammer(plan, genesis_constants.PRE_FUNDED_ACCOUNTS, all_el_client_contexts[0])

    return all_mevboost_contexts