## This is an ``include`` file used by ``cligen.nim`` proper to initialize the
## ``clCfg`` global.  Here we use only a TOML config file to do so.  You must
## add parsetoml to your compile setup via nimble install parsetoml or elsewise.

import std/[strformat, sequtils, tables], parsetoml
const cgConfigFileBaseName = "config.toml"

proc apply(c: var ClCfg, cfgFile: string, plain=false) =
  template hl(x): string = specifierHighlight(x, Whitespace, plain,
                                              keepPct=false, termInAttr=false)
  var rendOpts: Table[string, string]
  let
    tomlCfg = parsetoml.parseFile(cfgFile).getTable()
  for k1, v1 in tomlCfg.pairs:
    case k1.toLowerAscii()
    of "includes":
      let
        includeFiles = v1.getElems().mapIt(it.getStr())
      for f in includeFiles:
        if f == cfgFile: continue # disallow infinite loop
        var f = f
        if f == f.toUpperAscii(): f = getEnv(f)
        if not f.startsWith('/'): f = cfgFile.parentDir() / f
        if f.existsFile(): c.apply(f, plain)
    of "global", "aliases":
      for k2, v2 in v1.getTable().pairs:
        case k2.toLowerAscii()
        of "colors":
          for k3, v3 in v2.getTable().pairs:
            # echo &"    {k1}.{k2}.{k3} = {v3} "
            textAttrAlias(k3, v3.getStr().strip())
        else:
          stderr.write(&"{cfgFile}: unknown keyword {k2} in the [{k1}] section\n")
    of "layout":
      for k2, v2 in v1.getTable().pairs:
        case k2.toLowerAscii()
        of "rowsep", "rowseparator": c.hTabRowSep = v2.getStr()
        of "colgap", "columngap": c.hTabColGap = v2.getInt()
        of "minlast", "leastfinal": c.hTabMinLast = v2.getInt()
        of "cols", "columns":
          c.hTabCols.setLen 0
          for tok in v2.getElems().mapIt(it.getStr()): c.hTabCols.add parseEnum[ClHelpCol](tok)
        else:
          stderr.write(&"{cfgFile}: unknown keyword {k2} in the [{k1}] section\n")
    of "syntax":
      for k2, v2 in v1.getTable().pairs:
        case k2.toLowerAscii()
        of "reqsep", "requireseparator": c.reqSep = v2.getBool()
        of "sepchars", "separatorchars":
          c.sepChars = {}
          for ch in v2.getElems().mapIt(it.getStr()[0]):
            c.sepChars.incl(ch)
        else:
          stderr.write(&"{cfgFile}: unknown keyword {k2} in the [{k1}] section\n")
    of "color":
      if not plain:
        for k2, v2 in v1.getTable().pairs:
          let
            colorStr = textAttrOn(v2.getElems().mapIt(it.getStr()))
          case k2.toLowerAscii()
          of "optkeys", "options", "switches", "optkey", "option", "switch":
            c.helpAttr["clOptKeys"] = colorStr
          of "valtypes", "valuetypes", "types", "valtype", "valuetype", "type":
            c.helpAttr["clValType"] = colorStr
          of "dflvals", "defaultvalues", "dflval", "defaultvalue":
            c.helpAttr["clDflVal"] = colorStr
          of "descrips", "descriptions", "paramdescriptions", "descrip", "description", "paramdescription":
            c.helpAttr["clDescrip"] = colorStr
          of "cmd", "command", "cmdname", "commandname":
            c.helpAttr["cmd"] = colorStr
          of "doc", "documentation", "overalldocumentation":
            c.helpAttr["doc"] = colorStr
          of "args", "arguments", "argsonlinewithcmd":
            c.helpAttr["args"] = colorStr
          else:
            stderr.write(&"{cfgFile}: unknown keyword {k2} in the [{k1}] section\n")
    of "render":
      for k2, v2 in v1.getTable().pairs:
        case k2.toLowerAscii()
        of "singlestar": rendOpts["singlestar"] = v2.getStr
        of "doublestar": rendOpts["doublestar"] = v2.getStr
        of "triplestar": rendOpts["triplestar"] = v2.getStr
        of "singlebquo": rendOpts["singlebquo"] = v2.getStr
        of "doublebquo": rendOpts["doublebquo"] = v2.getStr
        else: stderr.write(&"{cfgFile}: unknown keyword {k2} in [{k1}]\n")
    of "templates":
      for k2, v2 in v1.getTable().pairs:
        let
          templStr = v2.getStr().strip()
        # echo &"  {k1}.{k2} = `{templStr}'"
        case k2.toLowerAscii()
        of "usageheader", "usehdr" : c.useHdr     = hl(templStr)
        of "usage", "use"          : c.use        = hl(templStr)
        of "usagemulti", "usemulti": c.useMulti   = hl(templStr)
        of "helpsyntax"            : c.helpSyntax = hl(e.value)
        else:
          stderr.write(&"{cfgFile}: unknown keyword {k2} in the [{k1}] section\n")
    else:
      stderr.write(&"{cfgFile}: unknown keyword {k1}\n")
  if rendOpts.len > 0:
    let r = initRstMdSGR(rendOpts, plain)
    proc renderMarkup(m: string): string = r.render(m)
    c.render = renderMarkup

var cfNm = getEnv("CLIGEN", os.getConfigDir()/"cligen"/cgConfigFileBaseName)
if cfNm.existsFile: clCfg.apply(move(cfNm), existsEnv("NO_COLOR"))
elif cfNm.splitPath.head == "config" and (cfNm/cgConfigFileBaseName).existsFile:
  clCfg.apply(cfNm/cgConfigFileBaseName, existsEnv("NO_COLOR"))
# Any given end CL user likely wants just one global system of color aliases.
# Default to leaving initial ones defined, but clear if an env.var says to.
if existsEnv("CLIGEN_COLORS_CLEAR"): textAttrAliasClear()
