use crate::config::dfx_version_str;
use indicatif::{MultiProgress, ProgressDrawTarget};
use slog::{Drain, Level, Logger, OwnedKVList, Record};
use std::fs::File;
use std::path::PathBuf;
use std::sync::Mutex;

/// The logging mode to use.
pub enum LoggingMode {
    /// The default mode for logging; output without any decoration, to STDERR.
    Stderr,

    /// Tee logging to a file (in addition to STDERR). This mimics the verbose flag.
    /// So it would be similar to `dfx ... |& tee /some/file.txt
    Tee(PathBuf),

    /// Output Debug logs and up to a file, regardless of verbosity, keep the STDERR output
    /// the same (with verbosity).
    File(PathBuf),
}

/// A Slog formatter that writes to a term decorator.
pub struct DfxFormat<D>
where
    D: slog_term::Decorator,
{
    decorator: D,
}

impl<D: slog_term::Decorator> DfxFormat<D> {
    pub fn new(decorator: D) -> DfxFormat<D> {
        DfxFormat { decorator }
    }
}

impl<D: slog_term::Decorator> slog::Drain for DfxFormat<D> {
    type Ok = ();
    type Err = std::io::Error;

    fn log(
        &self,
        record: &slog::Record<'_>,
        values: &slog::OwnedKVList,
    ) -> Result<Self::Ok, Self::Err> {
        self.decorator.with_record(record, values, |decorator| {
            if record.level() <= slog::Level::Warning {
                decorator.start_level()?;
                write!(decorator, "{}: ", record.level().as_str())?;
                // start_whitespace resets to normal coloring after printing the level
                decorator.start_whitespace()?;
            }

            decorator.start_msg()?;
            write!(decorator, "{}", record.msg())?;

            decorator.start_whitespace()?;
            writeln!(decorator)?;

            decorator.flush()?;
            Ok(())
        })
    }
}

/// Create a log drain.
fn create_drain(mode: LoggingMode) -> Logger {
    match mode {
        LoggingMode::Stderr => {
            let decorator = slog_term::TermDecorator::new().build();
            let drain = DfxFormat::new(decorator).fuse();
            let mutex_drain = Mutex::new(drain).fuse();
            Logger::root(mutex_drain, slog::o!())
        }
        LoggingMode::File(out) => {
            let file = File::create(out).expect("Couldn't open log file");
            let decorator = slog_term::PlainDecorator::new(file);
            let drain = slog_term::FullFormat::new(decorator).build().fuse();
            Logger::root(slog_async::Async::new(drain).build().fuse(), slog::o!())
        }
        // A Tee mode is basically 2 drains duplicated.
        LoggingMode::Tee(out) => Logger::root(
            slog::Duplicate::new(
                create_drain(LoggingMode::Stderr),
                create_drain(LoggingMode::File(out)),
            )
            .fuse(),
            slog::o!(),
        ),
    }
}

/// Create a root logger. The logger will freeze any spinners from the accompanying MultiProgress while logging;
/// accordingly, all spinners should be made from `env.new_spinner()`.
///
/// The verbose_level can be negative, in which case it's a quiet mode which removes warnings,
/// then errors entirely.
pub fn create_root_logger(verbose_level: i64, mode: LoggingMode) -> (Logger, MultiProgress) {
    let log_level = match verbose_level {
        -3 => Level::Critical,
        -2 => Level::Error,
        -1 => Level::Warning,
        0 => Level::Info,
        1 => Level::Debug,
        x => {
            if x > 0 {
                Level::Trace
            } else {
                return (
                    Logger::root(slog::Discard, slog::o!()),
                    MultiProgress::new(),
                );
            }
        }
    };

    let spinners = MultiProgress::new();
    spinners.set_draw_target(ProgressDrawTarget::stderr());
    let drain = slog::LevelFilter::new(create_drain(mode), log_level).fuse();
    let drain = IndicatifCompat {
        inner: drain,
        spinners: spinners.clone(),
    };
    (
        Logger::root(drain, slog::o!("version" => dfx_version_str())),
        spinners,
    )
}

struct IndicatifCompat<D> {
    inner: D,
    spinners: MultiProgress,
}

impl<D: Drain> Drain for IndicatifCompat<D> {
    type Ok = D::Ok;
    type Err = D::Err;
    fn log(&self, record: &Record, values: &OwnedKVList) -> Result<Self::Ok, Self::Err> {
        self.spinners.suspend(|| self.inner.log(record, values))
    }
    #[inline]
    fn is_enabled(&self, level: Level) -> bool {
        self.inner.is_enabled(level)
    }
}
