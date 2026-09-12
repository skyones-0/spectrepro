//! Build logic for SpectrePro. A single "build.zig" file became far too complex
//! and spaghetti, so this package extracts the build logic into smaller,
//! more manageable pieces.

pub const gtk = @import("gtk.zig");
pub const Config = @import("Config.zig");
pub const GitVersion = @import("GitVersion.zig");

// Artifacts
pub const SpectreProBench = @import("SpectreProBench.zig");
pub const SpectreProDist = @import("SpectreProDist.zig");
pub const SpectreProDocs = @import("SpectreProDocs.zig");
pub const SpectreProExe = @import("SpectreProExe.zig");
pub const SpectreProFrameData = @import("SpectreProFrameData.zig");
pub const SpectreProLib = @import("SpectreProLib.zig");
pub const SpectreProLibVt = @import("SpectreProLibVt.zig");
pub const SpectreProResources = @import("SpectreProResources.zig");
pub const SpectreProI18n = @import("SpectreProI18n.zig");
pub const SpectreProXcodebuild = @import("SpectreProXcodebuild.zig");
pub const SpectreProXCFramework = @import("SpectreProXCFramework.zig");
pub const SpectreProWebdata = @import("SpectreProWebdata.zig");
pub const SpectreProZig = @import("SpectreProZig.zig");
pub const HelpStrings = @import("HelpStrings.zig");
pub const SharedDeps = @import("SharedDeps.zig");
pub const UnicodeTables = @import("UnicodeTables.zig");

// Steps
pub const LibtoolStep = @import("LibtoolStep.zig");
pub const LipoStep = @import("LipoStep.zig");
pub const MetallibStep = @import("MetallibStep.zig");
pub const XCFrameworkStep = @import("XCFrameworkStep.zig");

// Helpers
pub const requireZig = @import("zig.zig").requireZig;
