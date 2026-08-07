# blind read scoring sheet
# row: (n, score, families, ending_shape, keep)
A = [
(1,15,"","fact",0),(2,60,"BUTTON","joke",0),(3,45,"NEG","fact",0),(4,12,"","instruction",0),
(5,55,"BUTTON","verdict",0),(6,10,"","instruction",0),(7,35,"","fact",0),
(8,80,"NEG OBJECT MOTIF BUTTON","instruction",1),(9,12,"","unresolved",0),
(10,65,"NEG OVERAUTH UNIFORM","instruction",0),(11,30,"","instruction",0),
(12,78,"BUTTON UNIFORM MOTIF","epigram",1),(13,10,"","instruction",0),(14,42,"","verdict",0),
(15,40,"MOTIF","fact",0),(16,45,"","verdict",0),(17,68,"OBJECT UNIFORM","fact",1),
(18,82,"NEG BUTTON MOTIF UNIFORM OBJECT","motion",1),(19,22,"","instruction",0),
(20,58,"BUTTON","joke",0),(21,72,"BUTTON UNIFORM","verdict",0),(22,55,"BUTTON","reversal",1),
(23,85,"BUTTON MOTIF OBJECT UNIFORM","verdict",1),(24,48,"","instruction",0),
(25,12,"","unresolved",0),(26,12,"","instruction",0),(27,30,"","verdict",0),
(28,30,"","instruction",0),(29,50,"BUTTON","fact",0),(30,20,"","fact",0),
(31,70,"BUTTON UNIFORM MOTIF","verdict",0),(32,62,"NEG MOTIF BUTTON","instruction",0),
(33,10,"","unresolved",0),(34,48,"","fact",0),(35,86,"BUTTON UNIFORM","verdict",1),
(36,65,"OVERAUTH BUTTON UNIFORM","instruction",0),(37,10,"","instruction",0),
(38,12,"","fact",0),(39,15,"","fact",0),(40,30,"","fact",0),(41,8,"","unresolved",0),
(42,8,"","unresolved",0),(43,22,"","unresolved",0),(44,52,"BUTTON OVERAUTH","joke",0),
(45,12,"","instruction",0),(46,40,"","verdict",0),(47,55,"MOTIF BUTTON","verdict",0),
(48,10,"","fact",0),(49,25,"","fact",0),(50,25,"","fact",0),(51,62,"BUTTON","verdict",0),
(52,58,"BUTTON","unresolved",0),(53,78,"OVERAUTH BUTTON NEG UNIFORM","epigram",0),
(54,28,"","instruction",0),(55,30,"","instruction",0),(56,12,"","instruction",0),
(57,62,"MOTIF BUTTON","unresolved",0),(58,72,"NEG BUTTON","motion",1),(59,12,"","fact",0),
(60,70,"MOTIF BUTTON","instruction",0),(61,66,"MOTIF BUTTON","instruction",0),
(62,20,"","fact",0),(63,55,"OBJECT","instruction",0),(64,10,"","fact",0),
(65,60,"","verdict",0),(66,65,"NEG BUTTON UNIFORM","joke",0),(67,52,"","joke",0),
(68,15,"","unresolved",0),(69,55,"BUTTON","verdict",0),(70,15,"","fact",0),
(71,58,"MOTIF UNIFORM","fact",0),(72,15,"","unresolved",0),
(73,74,"BUTTON UNIFORM OBJECT","instruction",0),(74,62,"BUTTON UNIFORM","joke",0),
(75,50,"BUTTON","joke",0),(76,28,"","fact",0),(77,66,"UNIFORM BUTTON","unresolved",0),
(78,52,"NEG","unresolved",0),(79,48,"MOTIF","fact",0),(80,15,"","unresolved",0),
(81,12,"","fact",0),(82,15,"","instruction",0),(83,55,"NEG BUTTON","instruction",0),
(84,60,"UNIFORM","instruction",0),(85,30,"","instruction",0),
(86,68,"BUTTON OBJECT UNIFORM","verdict",0),(87,40,"MOTIF","fact",0),
(88,66,"MOTIF BUTTON UNIFORM","joke",0),(89,25,"","instruction",0),(90,55,"MOTIF","instruction",0),
(91,55,"","fact",0),(92,15,"","instruction",0),(93,15,"","fact",0),
(94,66,"NEG MOTIF OVERAUTH","instruction",0),(95,28,"","interruption",0),(96,25,"","unresolved",0),
(97,12,"","instruction",0),(98,72,"NEG MOTIF BUTTON","instruction",1),(99,45,"","verdict",0),
(100,15,"","fact",0),(101,55,"OBJECT","instruction",0),(102,62,"BUTTON UNIFORM","epigram",1),
(103,48,"","verdict",0),(104,35,"","unresolved",0),(105,42,"","fact",0),(106,12,"","fact",0),
(107,72,"BUTTON UNIFORM MOTIF","fact",0),(108,62,"OBJECT BUTTON","unresolved",0),
(109,20,"","unresolved",0),(110,52,"MOTIF","fact",0),
(111,84,"BUTTON UNIFORM MOTIF OVERAUTH","instruction",1),(112,65,"MOTIF BUTTON","verdict",0),
(113,62,"MOTIF BUTTON","unresolved",0),(114,62,"BUTTON MOTIF","verdict",0),
(115,70,"NEG BUTTON OVERAUTH","fact",0),(116,74,"MOTIF BUTTON OBJECT UNIFORM","verdict",0),
(117,40,"","joke",0),(118,58,"MOTIF BUTTON","fact",0),(119,40,"NEG","instruction",0),
(120,50,"","epigram",0),
]

B = [
(1,52,"OBJECT","fact",0),(2,80,"OBJECT BUTTON","fact",0),(3,60,"OBJECT","fact",0),
(4,48,"OBJECT","fact",0),(5,68,"NEG UNIFORM","instruction",0),
(6,68,"MOTIF OBJECT BUTTON","motion",0),(7,70,"BUTTON UNIFORM","verdict",0),
(8,25,"","motion",0),(9,66,"OVERAUTH BUTTON","fact",0),(10,68,"BUTTON","fact",1),
(11,80,"BUTTON OBJECT MOTIF","verdict",1),(12,64,"OVERAUTH BUTTON","fact",0),
(13,52,"OVERAUTH BUTTON","fact",0),(14,70,"OBJECT BUTTON","fact",0),(15,25,"","fact",0),
(16,66,"OBJECT BUTTON","verdict",0),(17,74,"OVERAUTH BUTTON NEG","epigram",0),
(18,35,"","fact",0),(19,58,"OBJECT","fact",0),(20,66,"NEG BUTTON","fact",0),
(21,40,"","fact",0),(22,45,"OVERAUTH","fact",0),(23,68,"BUTTON MOTIF UNIFORM","joke",1),
(24,72,"OVERAUTH BUTTON OBJECT","instruction",0),(25,45,"","fact",0),(26,55,"","fact",0),
(27,50,"","fact",0),(28,18,"","fact",0),(29,72,"OVERAUTH BUTTON","instruction",0),
(30,70,"OVERAUTH BUTTON OBJECT","fact",0),(31,35,"","fact",0),(32,50,"","fact",0),
(33,60,"UNIFORM BUTTON","motion",0),(34,68,"BUTTON OBJECT","epigram",0),
(35,20,"","instruction",0),(36,32,"MOTIF","fact",0),(37,32,"","fact",0),
(38,74,"OBJECT BUTTON UNIFORM","verdict",0),(39,58,"OBJECT","fact",0),(40,32,"","fact",0),
(41,70,"NEG OBJECT","fact",0),(42,74,"BUTTON OVERAUTH","reversal",1),
(43,62,"MOTIF BUTTON","fact",0),(44,55,"NEG OVERAUTH","unresolved",0),
(45,55,"MOTIF BUTTON","joke",0),(46,32,"","fact",0),(47,55,"BUTTON","fact",0),
(48,50,"OBJECT","fact",0),(49,20,"","fact",0),(50,25,"","instruction",0),
(51,52,"OBJECT","fact",0),(52,70,"BUTTON UNIFORM","verdict",0),
(53,64,"OBJECT OVERAUTH","fact",0),(54,48,"","fact",0),(55,15,"","fact",0),
(56,50,"OBJECT","fact",0),(57,50,"OBJECT","fact",0),(58,22,"","motion",1),
(59,30,"MOTIF","motion",0),(60,25,"","fact",0),(61,48,"OVERAUTH","instruction",0),
(62,56,"OBJECT BUTTON","fact",0),(63,58,"OVERAUTH BUTTON","verdict",0),
(64,78,"NEG OBJECT BUTTON","epigram",0),(65,78,"BUTTON OBJECT","verdict",1),
(66,70,"NEG BUTTON","verdict",0),(67,70,"OVERAUTH BUTTON","fact",0),
(68,55,"OVERAUTH BUTTON","fact",0),(69,60,"OBJECT","instruction",0),(70,30,"","fact",0),
(71,62,"OBJECT BUTTON","fact",0),(72,78,"BUTTON MOTIF UNIFORM","verdict",0),
(73,22,"","fact",0),(74,40,"","fact",0),(75,68,"OVERAUTH BUTTON MOTIF","joke",0),
(76,38,"","fact",0),(77,62,"BUTTON","fact",0),(78,15,"","fact",0),(79,25,"","fact",0),
(80,62,"NEG BUTTON","fact",0),(81,68,"OBJECT BUTTON","joke",0),
(82,60,"OBJECT OVERAUTH","fact",0),(83,76,"BUTTON OBJECT","verdict",1),(84,28,"","fact",0),
(85,32,"","fact",0),(86,48,"OBJECT","verdict",0),(87,55,"OBJECT","fact",0),
(88,55,"","fact",0),(89,58,"NEG BUTTON","fact",0),(90,50,"BUTTON","verdict",0),
(91,40,"","silence",0),(92,25,"","instruction",0),(93,35,"","fact",0),(94,48,"","silence",0),
(95,78,"BUTTON OBJECT","verdict",1),(96,60,"OVERAUTH BUTTON","instruction",0),
(97,22,"","fact",0),(98,40,"","fact",0),(99,30,"","fact",0),(100,52,"","fact",0),
(101,58,"BUTTON","epigram",0),(102,55,"BUTTON","fact",0),(103,32,"","fact",0),
(104,30,"","fact",0),(105,76,"BUTTON MOTIF UNIFORM","verdict",0),(106,35,"","instruction",0),
(107,40,"","fact",0),(108,42,"","fact",0),(109,25,"","fact",0),(110,30,"","fact",0),
(111,72,"OBJECT BUTTON","joke",0),(112,66,"OVERAUTH BUTTON","fact",0),(113,48,"","fact",0),
(114,58,"OBJECT","motion",0),(115,30,"","fact",0),(116,50,"","motion",0),(117,38,"","fact",0),
(118,52,"OBJECT BUTTON","joke",0),(119,15,"","instruction",0),(120,55,"BUTTON","fact",0),
]

C = [
(1,68,"BUTTON OBJECT","joke",0),(2,25,"","fact",0),(3,42,"","fact",0),(4,66,"BUTTON","instruction",0),
(5,72,"BUTTON MOTIF UNIFORM","verdict",0),(6,58,"OVERAUTH","fact",0),(7,45,"NEG","fact",0),
(8,8,"","fact",0),(9,12,"","unresolved",0),(10,70,"BUTTON OBJECT","verdict",0),
(11,48,"OVERAUTH MOTIF","instruction",0),(12,64,"UNIFORM BUTTON","fact",0),
(13,64,"OBJECT BUTTON","verdict",0),(14,15,"","instruction",0),(15,58,"BUTTON OVERAUTH","joke",0),
(16,62,"BUTTON OVERAUTH","fact",0),(17,72,"BUTTON UNIFORM","verdict",0),
(18,52,"NEG BUTTON","joke",1),(19,68,"BUTTON NEG","joke",0),(20,30,"","instruction",0),
(21,66,"UNIFORM BUTTON","motion",0),(22,72,"NEG OVERAUTH BUTTON","unresolved",0),
(23,8,"","unresolved",0),(24,72,"UNIFORM BUTTON OBJECT","joke",0),(25,58,"MOTIF","fact",0),
(26,15,"","instruction",0),(27,55,"UNIFORM","instruction",0),
(28,86,"BUTTON OBJECT UNIFORM","epigram",0),(29,55,"BUTTON","fact",0),
(30,65,"OBJECT BUTTON","verdict",0),(31,15,"","instruction",0),
(32,82,"NEG BUTTON OVERAUTH","verdict",0),(33,62,"BUTTON UNIFORM","motion",0),
(34,20,"","fact",0),(35,15,"","fact",0),(36,62,"BUTTON UNIFORM","joke",0),
(37,25,"","instruction",0),(38,55,"BUTTON","joke",0),(39,55,"OVERAUTH","unresolved",0),
(40,74,"BUTTON OVERAUTH","instruction",0),(41,82,"BUTTON UNIFORM OBJECT","verdict",0),
(42,72,"OVERAUTH BUTTON","instruction",0),(43,52,"BUTTON","instruction",0),
(44,72,"NEG OBJECT BUTTON","fact",0),(45,15,"","fact",0),
(46,72,"NEG OBJECT BUTTON","verdict",0),(47,32,"","fact",0),(48,32,"","fact",0),
(49,40,"","fact",0),(50,35,"","verdict",0),(51,66,"BUTTON","verdict",0),
(52,74,"OBJECT BUTTON","epigram",0),(53,78,"MOTIF BUTTON UNIFORM","verdict",1),
(54,15,"","instruction",0),(55,58,"OVERAUTH BUTTON","fact",0),
(56,76,"BUTTON OVERAUTH","verdict",0),(57,30,"","instruction",0),
(58,62,"BUTTON MOTIF","epigram",0),(59,32,"","instruction",0),
(60,70,"BUTTON UNIFORM","verdict",0),(61,62,"OVERAUTH MOTIF","instruction",0),
(62,60,"MOTIF BUTTON","joke",0),(63,48,"","fact",0),(64,35,"","unresolved",0),
(65,50,"MOTIF","fact",0),(66,12,"","fact",0),(67,86,"BUTTON UNIFORM MOTIF","epigram",1),
(68,70,"BUTTON MOTIF","verdict",0),(69,10,"","instruction",0),
(70,70,"BUTTON UNIFORM","verdict",0),(71,12,"","fact",0),
(72,62,"BUTTON OVERAUTH","verdict",0),(73,45,"OVERAUTH","fact",0),
(74,62,"MOTIF BUTTON","verdict",0),(75,55,"MOTIF","fact",0),(76,12,"","fact",0),
(77,68,"UNIFORM BUTTON","instruction",0),(78,62,"MOTIF BUTTON","fact",0),
(79,80,"BUTTON MOTIF UNIFORM","joke",1),(80,45,"MOTIF","unresolved",0),
(81,48,"OVERAUTH","fact",0),(82,68,"OBJECT BUTTON","fact",0),
(83,58,"UNIFORM BUTTON","instruction",0),(84,15,"","unresolved",0),
(85,66,"OBJECT BUTTON","verdict",0),(86,35,"","fact",0),(87,25,"","fact",0),
(88,42,"","instruction",0),(89,30,"","instruction",0),(90,52,"BUTTON","epigram",0),
(91,62,"BUTTON UNIFORM","joke",0),(92,32,"","fact",0),(93,66,"BUTTON","fact",0),
(94,76,"BUTTON UNIFORM","fact",0),(95,84,"NEG BUTTON UNIFORM MOTIF","instruction",1),
(96,15,"","instruction",0),(97,25,"","fact",0),(98,35,"","fact",0),
(99,70,"BUTTON OBJECT","epigram",0),(100,45,"","unresolved",0),
(101,80,"NEG OBJECT BUTTON","verdict",0),(102,25,"","fact",0),
(103,66,"NEG OVERAUTH","fact",0),(104,84,"NEG OBJECT BUTTON OVERAUTH","epigram",0),
(105,10,"","instruction",0),(106,80,"BUTTON MOTIF UNIFORM","epigram",0),
(107,48,"","silence",0),(108,8,"","unresolved",0),(109,30,"","instruction",0),
(110,30,"","fact",0),(111,55,"OVERAUTH BUTTON","fact",0),(112,55,"BUTTON","joke",0),
(113,50,"BUTTON","joke",0),(114,10,"","unresolved",0),(115,40,"","instruction",0),
(116,30,"","fact",0),(117,10,"","unresolved",0),(118,45,"","fact",0),(119,42,"","fact",0),
(120,48,"","instruction",0),(121,32,"","fact",0),
(122,86,"NEG BUTTON UNIFORM OVERAUTH","epigram",1),(123,55,"NEG OVERAUTH","instruction",0),
(124,80,"MOTIF BUTTON UNIFORM","epigram",1),(125,50,"","motion",0),(126,52,"OBJECT","fact",0),
(127,50,"NEG BUTTON","joke",1),(128,45,"","instruction",0),(129,35,"","unresolved",0),
(130,66,"BUTTON UNIFORM","joke",0),(131,70,"MOTIF OBJECT BUTTON","motion",0),
(132,72,"BUTTON","epigram",0),(133,8,"","fact",0),
(134,84,"BUTTON MOTIF UNIFORM OBJECT","verdict",0),(135,15,"","instruction",0),
(136,72,"NEG BUTTON OVERAUTH","verdict",0),(137,62,"OBJECT OVERAUTH","instruction",0),
(138,30,"","fact",0),(139,58,"BUTTON","verdict",0),(140,55,"BUTTON OVERAUTH","unresolved",0),
(141,55,"OBJECT","fact",0),(142,35,"","fact",0),(143,25,"","fact",0),
(144,72,"NEG BUTTON UNIFORM","epigram",0),(145,12,"","fact",0),(146,30,"","fact",0),
(147,50,"BUTTON OVERAUTH","unresolved",0),(148,32,"","instruction",0),
(149,80,"MOTIF BUTTON UNIFORM","verdict",0),(150,40,"","unresolved",1),
(151,74,"NEG MOTIF BUTTON","verdict",0),(152,42,"","fact",0),
(153,55,"OVERAUTH BUTTON","unresolved",0),(154,55,"OBJECT","fact",0),
(155,64,"MOTIF BUTTON","joke",0),(156,78,"OBJECT BUTTON","verdict",1),
(157,52,"OVERAUTH","fact",0),(158,20,"","fact",0),
(159,78,"NEG BUTTON UNIFORM MOTIF","instruction",1),(160,50,"MOTIF","fact",0),
(161,45,"","fact",0),(162,70,"NEG BUTTON","verdict",0),
(163,70,"NEG BUTTON OVERAUTH","instruction",0),(164,8,"","unresolved",0),
(165,40,"","verdict",0),(166,78,"BUTTON UNIFORM OBJECT","verdict",1),
(167,78,"BUTTON OBJECT","epigram",0),(168,50,"OVERAUTH","fact",0),(169,15,"","fact",0),
(170,50,"OVERAUTH","fact",0),(171,55,"BUTTON","verdict",0),
(172,60,"BUTTON OBJECT","verdict",0),(173,12,"","instruction",0),(174,58,"BUTTON","epigram",0),
(175,62,"BUTTON MOTIF","fact",0),(176,48,"","motion",0),(177,58,"UNIFORM BUTTON","unresolved",0),
(178,45,"","fact",0),(179,55,"OVERAUTH","fact",0),(180,62,"OBJECT","fact",0),
(181,72,"BUTTON OBJECT","epigram",0),(182,20,"","fact",0),
(183,62,"OBJECT BUTTON","unresolved",0),(184,55,"NEG MOTIF","instruction",0),
(185,86,"BUTTON MOTIF UNIFORM","verdict",1),(186,55,"BUTTON","fact",0),(187,30,"","fact",0),
(188,80,"NEG BUTTON UNIFORM OBJECT","verdict",1),(189,58,"BUTTON","verdict",0),
(190,30,"","fact",0),(191,72,"BUTTON UNIFORM","fact",0),(192,28,"","unresolved",0),
(193,40,"","verdict",0),(194,35,"","fact",0),(195,68,"BUTTON UNIFORM","instruction",0),
(196,55,"BUTTON UNIFORM","unresolved",0),(197,55,"BUTTON","joke",0),
(198,78,"BUTTON OBJECT UNIFORM","joke",0),(199,80,"OVERAUTH BUTTON","epigram",0),
(200,70,"OBJECT","fact",0),(201,84,"NEG BUTTON OBJECT UNIFORM","epigram",0),
(202,80,"NEG BUTTON","interruption",1),(203,62,"OVERAUTH BUTTON","joke",0),
(204,32,"","fact",0),(205,50,"BUTTON","joke",1),(206,40,"","fact",0),(207,20,"","fact",0),
(208,62,"OVERAUTH BUTTON","fact",0),(209,12,"","fact",0),(210,30,"","fact",0),
(211,35,"","fact",0),(212,8,"","fact",0),(213,66,"BUTTON MOTIF","fact",0),
(214,35,"","fact",0),(215,25,"","unresolved",0),(216,72,"NEG BUTTON OBJECT","verdict",0),
(217,62,"MOTIF BUTTON","instruction",0),(218,68,"UNIFORM BUTTON OBJECT","verdict",0),
(219,62,"NEG OVERAUTH BUTTON","unresolved",0),(220,20,"","instruction",0),
(221,52,"MOTIF","fact",0),(222,28,"","fact",0),(223,50,"MOTIF","fact",0),
(224,66,"BUTTON OBJECT","epigram",0),(225,58,"OVERAUTH OBJECT","silence",0),
(226,70,"UNIFORM BUTTON NEG","instruction",0),(227,48,"","motion",0),
]

import statistics as st
from collections import Counter

FAMS = ["NEG","BUTTON","OBJECT","MOTIF","UNIFORM","OVERAUTH"]

def report(name, rows):
    s = [r[1] for r in rows]
    n = len(rows)
    print("="*70)
    print(f"{name}  n={n}")
    print(f"mean={st.mean(s):.1f}  median={st.median(s)}  stdev={st.pstdev(s):.1f}")
    print(f"share >=76: {sum(1 for x in s if x>=76)/n*100:.1f}%  ({sum(1 for x in s if x>=76)} rows)")
    print(f"share <=35: {sum(1 for x in s if x<=35)/n*100:.1f}%  ({sum(1 for x in s if x<=35)} rows)")
    print(f"share 36-55: {sum(1 for x in s if 36<=x<=55)/n*100:.1f}%")
    print(f"share 56-75: {sum(1 for x in s if 56<=x<=75)/n*100:.1f}%")
    # deciles
    print("decile histogram:")
    for lo in range(0,100,10):
        c = sum(1 for x in s if lo <= x < lo+10)
        print(f"  {lo:3d}-{lo+9:3d}: {c:3d} {'#'*c}")
    # band histogram per rubric
    print("rubric bands:")
    bands = [(0,15),(16,35),(36,55),(56,75),(76,90),(91,100)]
    for lo,hi in bands:
        c = sum(1 for x in s if lo<=x<=hi)
        print(f"  {lo:3d}-{hi:3d}: {c:3d} ({c/n*100:.1f}%) {'#'*c}")
    # top/bottom
    srt = sorted(rows, key=lambda r:-r[1])
    print("top 8:", [(r[0],r[1]) for r in srt[:8]])
    print("bottom 8:", [(r[0],r[1]) for r in sorted(rows,key=lambda r:r[1])[:8]])
    # families
    print("family incidence:")
    for f in FAMS:
        rr = [r[0] for r in rows if f in r[2].split()]
        print(f"  {f:9s} {len(rr):3d}  ({len(rr)/n*100:.1f}%)")
    nf = sum(1 for r in rows if r[2]=="")
    print(f"  (no family flagged): {nf} ({nf/n*100:.1f}%)")
    multi = sum(1 for r in rows if len(r[2].split())>=3)
    print(f"  3+ families: {multi} ({multi/n*100:.1f}%)")
    # shapes
    print("ending-shape histogram:")
    cnt = Counter(r[3] for r in rows)
    for k,v in cnt.most_common():
        print(f"  {k:12s} {v:3d} ({v/n*100:.1f}%) {'#'*v}")
    keeps = [r[0] for r in rows if r[4]]
    print(f"keeps ({len(keeps)}):", keeps)
    ks = [r[1] for r in rows if r[4]]
    if ks: print(f"  keep mean score: {st.mean(ks):.1f}")
    nonkeep = [r[1] for r in rows if not r[4]]
    print(f"  non-keep mean: {st.mean(nonkeep):.1f}  non-keep median: {st.median(nonkeep)}")

for nm, rows in (("SET A",A),("SET B",B),("SET C (holdout)",C)):
    report(nm, rows)

print("="*70)
print("COMBINED A+B:", f"mean={st.mean([r[1] for r in A+B]):.1f}")
allrows = A+B+C
print("ALL:", f"mean={st.mean([r[1] for r in allrows]):.1f}")
