mod pocketic_config_port;
mod replica_port;
mod webserver_port;

use crate::commands::info::{replica_port::get_replica_port, webserver_port::get_webserver_port};
use crate::lib::agent::create_anonymous_agent_environment;
use crate::lib::error::DfxResult;
use crate::lib::info;
use crate::lib::named_canister::get_ui_canister_url;
use crate::lib::network::network_opt::NetworkOpt;
use crate::lib::telemetry::Telemetry;
use crate::Environment;
use anyhow::bail;
use clap::{Parser, Subcommand};
use dfx_core::config::model::dfinity::{NetworksConfig, ToolConfig};
use pocketic_config_port::get_pocketic_config_port;

#[derive(Subcommand, Clone, Debug)]
enum InfoType {
    /// Show the URL of the Candid UI canister
    CandidUiUrl,
    /// Show the headers that gets applied to assets in .ic-assets.json5 if "security_policy" is "standard" or "hardened".
    SecurityPolicy,
    /// Show the port of the local IC API/HTTP gateway
    WebserverPort,
    /// Show the revision of the replica shipped with this dfx binary
    ReplicaRev,
    /// Show the path to the network configuration file
    NetworksJsonPath,
    /// Show the path to the dfx configuration file
    ConfigJsonPath,
    /// Show the port the replica is using, if it is running
    ReplicaPort,
    /// Show the port that PocketIC is using, if it is running
    PocketicConfigPort,
    /// Show the path to the telemetry log file
    TelemetryLogPath,
    /// Show the effective canister ID that dfx will use for management canister calls that don't imply one
    DefaultEffectiveCanisterId,
}

#[derive(Parser)]
#[command(name = "info")]
/// Get information about the replica shipped with dfx, path to networks.json, and network ports of running replica.
pub struct InfoOpts {
    #[command(subcommand)]
    info_type: InfoType,

    #[command(flatten)]
    network: NetworkOpt,
}

pub fn exec(env: &dyn Environment, opts: InfoOpts) -> DfxResult {
    let value = match opts.info_type {
        InfoType::CandidUiUrl => {
            let env = create_anonymous_agent_environment(env, opts.network.to_network_name())?;
            match get_ui_canister_url(&env)? {
                Some(url) => url.to_string(),
                None => bail!(
                    "Candid UI not installed on network {}.",
                    env.get_network_descriptor().name
                ),
            }
        }
        InfoType::DefaultEffectiveCanisterId => {
            let env = create_anonymous_agent_environment(env, opts.network.to_network_name())?;
            env.get_effective_canister_id().to_text()
        }
        InfoType::SecurityPolicy => {
            ic_asset::security_policy::SecurityPolicy::Standard.to_json5_str()
        }
        InfoType::ReplicaPort => get_replica_port(env)?,
        InfoType::PocketicConfigPort => get_pocketic_config_port(env)?,
        InfoType::ReplicaRev => info::replica_rev().to_string(),
        InfoType::WebserverPort => get_webserver_port(env)?,
        InfoType::NetworksJsonPath => NetworksConfig::new()?.get_path().display().to_string(),
        InfoType::ConfigJsonPath => ToolConfig::new()?.config_path().display().to_string(),
        InfoType::TelemetryLogPath => Telemetry::get_log_path()?.display().to_string(),
    };
    println!("{}", value);
    Ok(())
}
