{ lib }:

let
  fail = message: throw "apm-dsl: ${message}";
  formatList = values: lib.concatStringsSep ", " values;

  getPin =
    lock: package:
    if builtins.hasAttr package lock then
      lock.${package}
    else
      fail "missing lock entry for package '${package}'";

  mkPinnedDependency =
    {
      lock,
      package,
      path ? null,
    }:
    let
      pin = getPin lock package;
      suffix = if path == null then "" else "/${path}";
    in
    "${pin.source}${suffix}#${pin.rev}";

  normalizeRequires =
    node:
    let
      requires = node.requires or { };
    in
    {
      skills = requires.skills or [ ];
      agents = requires.agents or [ ];
    };

  assertKnown =
    kind: known: owner: refs:
    let
      missing = builtins.filter (name: !(builtins.hasAttr name known)) refs;
    in
    if missing == [ ] then true else fail "${owner} references unknown ${kind}: ${formatList missing}";

  assertAgentLeaves =
    agents:
    let
      invalid = builtins.filter (name: agents.${name} ? requires) (builtins.attrNames agents);
    in
    if invalid == [ ] then
      true
    else
      fail "agents must be dependency leaves, but these declare requires: ${formatList invalid}";
in
{
  inherit mkPinnedDependency;

  mkPrimitiveDependencies =
    {
      lock,
      package,
      selectedSkills,
      skills,
      agents ? { },
      skillPath ? (name: "skills/${name}"),
      agentPath ? (name: "agents/${name}.agent.md"),
    }:
    let
      closeSkill =
        stack: name:
        if builtins.elem name stack then
          fail "skill dependency cycle detected: ${formatList (stack ++ [ name ])}"
        else if !(builtins.hasAttr name skills) then
          fail "selectedSkills references unknown skill: ${name}"
        else
          let
            requires = normalizeRequires skills.${name};
          in
          builtins.deepSeq [
            (assertKnown "skill" skills "skill '${name}'" requires.skills)
            (assertKnown "agent" agents "skill '${name}'" requires.agents)
          ] ([ name ] ++ builtins.concatLists (map (closeSkill (stack ++ [ name ])) requires.skills));

      validateSkill =
        name:
        let
          requires = normalizeRequires skills.${name};
        in
        builtins.deepSeq [
          (assertKnown "skill" skills "skill '${name}'" requires.skills)
          (assertKnown "agent" agents "skill '${name}'" requires.agents)
        ] true;

      skillClosure = lib.unique (builtins.concatLists (map (closeSkill [ ]) selectedSkills));
      agentClosure = lib.unique (
        builtins.concatLists (map (name: (normalizeRequires skills.${name}).agents) skillClosure)
      );
      validations = (map validateSkill (builtins.attrNames skills)) ++ [ (assertAgentLeaves agents) ];
    in
    builtins.deepSeq validations (
      (map (
        name:
        mkPinnedDependency {
          inherit lock package;
          path = skillPath name;
        }
      ) skillClosure)
      ++ (map (
        name:
        mkPinnedDependency {
          inherit lock package;
          path = agentPath name;
        }
      ) agentClosure)
    );
}
