{
  lib,
  python3,
  runCommand,
  # azooKey/azooKey_emoji_dictionary_storage checkout
  emojiSource,
  # charID.chid of the system dictionary hazkey-server loads
  charId,
}:

runCommand "hazkey-emoji-dictionary"
  {
    nativeBuildInputs = [ python3 ];
    meta = {
      description = "hazkey user dictionary that converts Japanese readings to emoji";
      # Readings come from Unicode CLDR annotations via azooKey.
      license = lib.licenses.unicode-dfs-2016;
      platforms = lib.platforms.linux;
    };
  }
  ''
    python3 -I ${./build.py} ${emojiSource} ${./frequency.tsv} ${./overrides.tsv} ${charId} $out
  ''
