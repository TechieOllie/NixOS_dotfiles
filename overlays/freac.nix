# fre:ac cannot encode anything as packaged in nixpkgs. This fixes that.
#
# The symptom is total and quiet: fre:ac starts, shows its UI, finds the
# CD drive, and offers exactly one output format — "meh", BoCA's built-in
# placeholder. `freaccmd --help` prints the same one-item list, which is
# the fastest way to check this from a shell.
#
# The cause is a naming mismatch nothing in the build can catch. BoCA
# loads codec libraries by dlopen()ing them under **unprefixed,
# unversioned** names relative to the binary's own directory —
# `codecs/FLAC.so`, `codecs/mp3lame.so` — because upstream fre:ac ships
# its own bundled copies there. nixpkgs installs the ordinary system
# libraries instead, which are named `libFLAC.so.14` and
# `libmp3lame.so.0`, and the packaged wrapper helpfully puts them on
# LD_LIBRARY_PATH — under names BoCA never asks for. So every codec
# component loads as a shared object (ldd is clean, nothing is missing)
# and then reports itself unavailable, and the build is perfectly green.
#
# The `codecs` directory has to be inside the store output. BoCA resolves
# it against the *installed* binary's path, not argv[0] or the cwd, so
# creating the directory next to a copy of the binary does nothing —
# verified by strace, which kept probing the original store path.
#
# Deliberately not sent upstream-as-a-patch here: this is a packaging bug
# in nixpkgs' freac/boca, and the fix belongs there. Until then this
# overlay is the whole reason overlays/ exists in this repo at all.
final: prev: {
  freac = prev.freac.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      mkdir -p $out/bin/codecs

      # Resolve each soname by glob rather than hardcoding a version, so a
      # nixpkgs bump that moves libFLAC.so.14 to .15 doesn't leave a
      # dangling symlink behind. Failing loudly on a miss is the point: a
      # silently absent codec is exactly the bug being fixed, and
      # noBrokenSymlinks would only catch the dangling case, not the
      # never-created one.
      linkCodec() {
        local dir="$1" soname="$2" want="$3" found
        found=$(ls -1 "$dir"/"$soname".so.* 2>/dev/null | grep -E '\.so\.[0-9]+$' | head -1)
        if [ -z "$found" ]; then
          echo "freac overlay: no $soname.so.N in $dir — BoCA would silently lose the $want codec" >&2
          exit 1
        fi
        ln -s "$found" "$out/bin/codecs/$want.so"
      }

      linkCodec ${final.flac.out}/lib      libFLAC      FLAC
      linkCodec ${final.lame.lib}/lib      libmp3lame   mp3lame
      linkCodec ${final.libogg}/lib        libogg       ogg
      linkCodec ${final.libvorbis}/lib     libvorbis    vorbis
      linkCodec ${final.libvorbis}/lib     libvorbisenc vorbisenc
      linkCodec ${final.libopus}/lib       libopus      opus
      linkCodec ${final.mpg123}/lib        libmpg123    mpg123
      linkCodec ${final.libsndfile.out}/lib libsndfile   sndfile

      # sndfile is the *decoder* side and is not optional in practice:
      # without it fre:ac cannot open a WAV or AIFF at all and answers
      # every conversion with "Could not process file". CD ripping itself
      # goes through libcdio rather than sndfile, so this is invisible if
      # the only thing ever tested is a disc — which is how it nearly got
      # left out here.
      #
      # Not linked, deliberately: MAC (Monkey's Audio), faad/fdk-aac/mp4v2
      # (the AAC family). Each would pull a further dependency in for a
      # format nothing on the one host using this needs, and the AAC path
      # is the reason `faac` has to be unfree-allowed at all. FLAC is what
      # this is for; MP3/Vorbis/Opus come along for free because their
      # libraries were already in the closure.

      # libcdio is how BoCA enumerates and reads the drive, and the stock
      # wrapper doesn't include it — without this fre:ac encodes fine and
      # then finds no CD to encode. These *are* looked up under proper
      # versioned sonames, so LD_LIBRARY_PATH is the right mechanism for
      # them, unlike the codecs above. Re-wrapping an already-wrapped
      # binary is supported (makeWrapper renames the inner one), and both
      # entry points need it — freaccmd is wrapped too.
      for prog in freac freaccmd; do
        wrapProgram "$out/bin/$prog" \
          --prefix LD_LIBRARY_PATH : "${
            final.lib.makeLibraryPath [
              final.libcdio
              final.libcdio-paranoia
            ]
          }"
      done
    '';
  });
}
