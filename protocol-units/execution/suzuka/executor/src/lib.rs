pub mod v1;

use aptos_api::runtime::Apis;
pub use aptos_crypto::hash::HashValue;
pub use aptos_types::{
	block_executor::partitioner::ExecutableBlock,
	block_executor::partitioner::ExecutableTransactions,
	block_metadata::BlockMetadata,
	transaction::signature_verified_transaction::SignatureVerifiedTransaction,
	transaction::{SignedTransaction, Transaction},
};

use movement_types::BlockCommitment;

use async_channel::Sender;

#[tonic::async_trait]
pub trait SuzukaExecutor {
	/// Runs the service
	async fn run_service(&self) -> Result<(), anyhow::Error>;

	/// Runs the necessary background tasks.
	async fn run_background_tasks(&self) -> Result<(), anyhow::Error>;

	/// Executes a block optimistically
	async fn execute_block_opt(
		&self,
		block: ExecutableBlock,
	) -> Result<BlockCommitment, anyhow::Error>;

	/// Sets the transaction channel.
	fn set_tx_channel(&mut self, tx_channel: Sender<SignedTransaction>);

	/// Gets the dyn API.
	fn get_apis(&self) -> Apis;

	/// Get block head height.
	async fn get_block_head_height(&self) -> Result<u64, anyhow::Error>;

	/// Build block metadata for a timestamp
	async fn build_block_metadata(
		&self,
		block_id: HashValue,
		timestamp: u64,
	) -> Result<BlockMetadata, anyhow::Error>;
}
