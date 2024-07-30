use crate::config::model::local_server_descriptor::LocalNetworkScopeDescriptor;
use crate::config::model::network_descriptor::NetworkDescriptor;
use crate::error::canister_id_store::EnsureCohesiveNetworkDirectoryError;
use std::path::Path;

/// A cohesive network directory is one in which the directory in question contains
/// a file `network-id`, which contains the same contents as the `network-id` file
/// in the network data directory.  In this way, after `dfx start --clean`, we
/// can later clean up data in project directories.
pub fn ensure_cohesive_network_directory(
    network_descriptor: &NetworkDescriptor,
    directory: &Path,
) -> Result<(), EnsureCohesiveNetworkDirectoryError> {
    let scope = network_descriptor
        .local_server_descriptor
        .as_ref()
        .map(|d| &d.scope);

    if let Some(LocalNetworkScopeDescriptor::Shared { network_id_path }) = &scope {
        if network_id_path.is_file() {
            let network_id = crate::fs::read_to_string(network_id_path)
                .map_err(EnsureCohesiveNetworkDirectoryError::ReadToString)?;
            let project_network_id_path = directory.join("network-id");
            let reset = directory.is_dir()
                && (!project_network_id_path.exists()
                    || crate::fs::read_to_string(&project_network_id_path)
                        .map_err(EnsureCohesiveNetworkDirectoryError::ReadToString)?
                        != network_id);

            if reset {
                crate::fs::remove_dir_all(directory)
                    .map_err(EnsureCohesiveNetworkDirectoryError::RemoveDirAll)?;
            };

            if !directory.exists() {
                crate::fs::create_dir_all(directory)
                    .map_err(EnsureCohesiveNetworkDirectoryError::CreateDirAll)?;
                crate::fs::write(&project_network_id_path, &network_id)
                    .map_err(EnsureCohesiveNetworkDirectoryError::Write)?;
            }
        }
    }

    Ok(())
}
