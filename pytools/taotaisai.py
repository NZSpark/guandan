#!/usr/bin/env python3
"""
淘汰赛 - 单败淘汰对阵脚本
参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》

输入：队伍名单 CSV（含当前积分、所属俱乐部/社团）
      支持 16 支、8 支、4 支队伍
输出：淘汰赛对阵表（树形 bracket）

规则：
- 按积分排种子位（积分高的对积分低的）
- 同一俱乐部/社团的队伍尽量分到不同半区和不同对阵
- 16 队标准对阵：1vs16, 8vs9 / 4vs13, 5vs12 / 3vs14, 6vs11 / 2vs15, 7vs10
"""

import csv
import sys
import argparse
from collections import defaultdict
from dataclasses import dataclass
from copy import deepcopy


# ── 队伍数据 ──────────────────────────────────────────────

@dataclass
class Team:
    tid: int
    name: str
    player1: str
    gender1: str
    player2: str
    gender2: str
    club: str
    score: float = 0.0

    def display(self) -> str:
        club_str = f" [{self.club}]" if self.club else ""
        return f"{self.name}({self.player1}/{self.player2}){club_str}"


# ── CSV 读取 ──────────────────────────────────────────────

def load_teams(csv_path: str) -> list:
    """从 CSV 读取队伍名单，返回列表。"""
    teams = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader, 1):
            name = row["队伍名称"].strip()
            if not name:
                continue
            score_str = row.get("当前积分", "0").strip()
            score = float(score_str) if score_str else 0.0
            team = Team(
                tid=i,
                name=name,
                player1=row["队员1"].strip(),
                gender1=row["性别1"].strip(),
                player2=row["队员2"].strip(),
                gender2=row["性别2"].strip(),
                club=row.get("所属俱乐部/社团", "").strip(),
                score=score,
            )
            teams.append(team)
    return teams


# ── 种子排位 ──────────────────────────────────────────────

def seed_teams(teams: list) -> list:
    """
    按积分降序给队伍排种子位。
    同积分时按队伍名称字母序排列（保证确定性）。
    """
    return sorted(teams, key=lambda t: (-t.score, t.name))


# ── 标准对阵模板 ────────────────────────────────────────
# 对位格式: (种子号1, 种子号2, 位置标签)
# 16 强：按标准锦标赛 bracket 排位
# 1#和2#分在不同半区，决赛才会相遇

BRACKET_16 = [
    (1, 16, "上半区①"),
    (8, 9,  "上半区②"),
    (5, 12, "上半区③"),
    (4, 13, "上半区④"),
    (3, 14, "下半区⑤"),
    (6, 11, "下半区⑥"),
    (7, 10, "下半区⑦"),
    (2, 15, "下半区⑧"),
]

BRACKET_8 = [
    (1, 8, "上半区①"),
    (4, 5, "上半区②"),
    (3, 6, "下半区③"),
    (2, 7, "下半区④"),
]

BRACKET_4 = [
    (1, 4, "半决赛①"),
    (2, 3, "半决赛②"),
]

def build_bracket(seeded: list, template: list) -> list:
    """根据种子排位和模板构建对阵表。"""
    seed_map = {i: team for i, team in enumerate(seeded, 1)}
    bracket = []
    for s1, s2, label in template:
        t1 = seed_map.get(s1)
        t2 = seed_map.get(s2)
        if t1 and t2:
            bracket.append((t1, t2, label))
    return bracket


# ── 同俱乐部冲突检测与解决 ────────────────────────────

def detect_same_club_clashes(bracket: list) -> list:
    """检测对阵表中同俱乐部直接对阵的情况。"""
    return [(a, b, label) for a, b, label in bracket
            if a.club and b.club and a.club == b.club]


def detect_half_conflicts(bracket: list) -> dict:
    """检测各半区内的同俱乐部问题。"""
    n = len(bracket)
    half = n // 2
    conflicts = {}
    for half_name, half_range in [("上半区", range(0, half)), ("下半区", range(half, n))]:
        club_counts = defaultdict(list)
        for idx in half_range:
            if idx >= n:
                break
            a, b, _ = bracket[idx]
            if a.club:
                club_counts[a.club].append(a.name)
            if b.club:
                club_counts[b.club].append(b.name)
        half_conflicts = {club: names for club, names in club_counts.items() if len(names) > 1}
        if half_conflicts:
            conflicts[half_name] = half_conflicts
    return conflicts


def team_positions_in_bracket(bracket: list) -> dict:
    """返回 {team.tid: bracket_index} 映射。"""
    positions = {}
    for idx, (a, b, _) in enumerate(bracket):
        positions[a.tid] = idx
        positions[b.tid] = idx
    return positions


def resolve_same_club(bracket: list, seeded: list) -> list:
    """
    尽量消除同俱乐部队伍在同一对阵中的情况。
    通过与对面半区同俱乐部不同的队伍交换来实现。
    """
    n = len(bracket)
    half = n // 2

    max_iterations = 20
    for iteration in range(max_iterations):
        clashes = detect_same_club_clashes(bracket)
        if not clashes:
            break

        club = clashes[0][0].club  # 处理第一个冲突
        positions = team_positions_in_bracket(bracket)

        # 收集该俱乐部所有队伍及其位置
        club_entries = []
        for idx, (a, b, _) in enumerate(bracket):
            if a.club == club:
                club_entries.append((a, idx, 0 if idx < half else 1))
            if b.club == club:
                club_entries.append((b, idx, 0 if idx < half else 1))

        if len(club_entries) < 2:
            break

        # 找需要移出的队伍：在同一半区中多余的队伍
        swapped = False
        for h in [0, 1]:
            entries_in_half = [e for e in club_entries if e[2] == h]
            if len(entries_in_half) <= 1:
                continue
            
            # 移出第一支多余队伍
            team_to_move, pos, _ = entries_in_half[1]
            opposite_half = 1 - h
            
            # 在对面的半区找可交换的队伍（不同俱乐部）
            for target_pos in range(opposite_half * half, min((opposite_half + 1) * half, n)):
                target_a, target_b, _ = bracket[target_pos]
                for target_team in [target_a, target_b]:
                    if target_team.club != club:
                        # 检查交换后目标半区不会有新的同俱乐部问题
                        old_bracket = bracket
                        bracket = _swap_teams(bracket, team_to_move, target_team)
                        new_clashes = detect_same_club_clashes(bracket)
                        if len(new_clashes) < len(clashes):
                            swapped = True
                            break
                        bracket = old_bracket
                if swapped:
                    break
            if swapped:
                break

        if not swapped:
            break  # 无法进一步优化

    return bracket


def _swap_teams(bracket: list, team_a: Team, team_b: Team) -> list:
    """交换对阵中两支队伍的位置，返回新对阵表。"""
    new_bracket = []
    for t1, t2, label in bracket:
        nt1 = team_b if t1.tid == team_a.tid else (team_a if t1.tid == team_b.tid else t1)
        nt2 = team_b if t2.tid == team_a.tid else (team_a if t2.tid == team_b.tid else t2)
        new_bracket.append((nt1, nt2, label))
    return new_bracket


# ── 输出 ──────────────────────────────────────────────────

def print_bracket(bracket: list, total_teams: int, seeded: list, title: str):
    """格式化输出淘汰赛对阵表。"""
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}")

    # 种子排位
    print(f"\n  ── 种子排位 (按积分) ──")
    print(f"  {'-'*55}")
    for i, t in enumerate(seeded, 1):
        club_str = f" [{t.club}]" if t.club else ""
        print(f"  种子 {i:2d}: {t.name:20s} {t.player1}/{t.player2:6s}  "
              f"积分:{t.score:5.1f}{club_str}")

    # 对阵表
    n = len(bracket)
    if n == 8:
        round_name = "1/8 决赛对阵 (16 → 8)"
    elif n == 4:
        round_name = "1/4 决赛对阵 (8 → 4)"
    elif n == 2:
        round_name = "半决赛对阵 (4 → 2)"
    else:
        round_name = "首轮对阵"

    print(f"\n  ── {round_name} ──")
    print(f"  {'-'*65}")

    for idx, (a, b, label) in enumerate(bracket, 1):
        club_a = f"[{a.club}]" if a.club else ""
        club_b = f"[{b.club}]" if b.club else ""
        same_club = ""
        if a.club and b.club and a.club == b.club:
            same_club = " ⚠ 同俱乐部!"

        print(f"\n  [{label}]")
        print(f"    {a.name:16s} ({a.player1}/{a.player2}) {club_a:20s}")
        print(f"    vs {b.name:16s} ({b.player1}/{b.player2}) {club_b:20s}{same_club}")

    # 晋级路线图
    if n >= 2:
        _print_bracket_tree(bracket)

    # 统计
    print(f"\n  ── 统计 ──")
    print(f"  总队伍数:  {total_teams}")
    print(f"  首轮对阵数: {len(bracket)}")

    clashes = detect_same_club_clashes(bracket)
    if clashes:
        print(f"  ⚠ 同俱乐部直接对阵: {len(clashes)} 组")
        for a, b, label in clashes:
            print(f"    - {label}: {a.name} vs {b.name} [{a.club}]")
    else:
        print(f"  同俱乐部直接对阵: 0 组 ✓")

    half_conflicts = detect_half_conflicts(bracket)
    if half_conflicts:
        print(f"  ⚠ 同半区同俱乐部 (可能在后续轮次相遇):")
        for half_name, conflicts in half_conflicts.items():
            for club, names in conflicts.items():
                print(f"    {half_name} [{club}]: {' / '.join(names)}")


def _print_bracket_tree(bracket: list):
    """打印树形晋级路线图。"""
    n = len(bracket)

    print(f"\n  ── 晋级路线图 ──")
    print(f"  {'-'*60}")

    if n == 8:
        # 16 > 8 > 4 > 2 > 1
        half = n // 2
        for i in range(half):
            a_up, b_up, _ = bracket[i]
            a_lo, b_lo, _ = bracket[half + i]

            print(f"  {a_up.name:14s} ─┐          {a_lo.name:14s} ─┐")
            print(f"  {b_up.name:14s} ─┤  QF{i+1}    {b_lo.name:14s} ─┤  QF{half+i+1}")

        print(f"                     ├── SF1 ─┐                ├── SF2 ─┐")
        print(f"                     │        ├── 决赛 (冠军)  │        │")
        print(f"                     │        │                │        │")
        print(f"                     ├── SF1 败者 ── 季军赛 ── SF2 败者 ┤")
    elif n == 4:
        for i, (a, b, label) in enumerate(bracket):
            l = label.replace("半决赛", "SF")
            print(f"  {a.name:14s} ─┐")
            print(f"  {b.name:14s} ─┤  {l}")
        print(f"                     ├── 决赛 (冠军)")
        print(f"                     └── 季军赛")
    elif n == 2:
        a, b, _ = bracket[0]
        c, d, _ = bracket[1]
        print(f"  {a.name:14s} ─┐          {c.name:14s} ─┐")
        print(f"  {b.name:14s} ─┘          {d.name:14s} ─┘")
        print(f"                     ├── 决赛 (冠军)")
        print(f"                     └── 季军赛")


def write_bracket_csv(bracket: list, seeded: list, filepath: str):
    """将淘汰赛对阵表输出为 CSV 文件。"""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["对阵标签", "队伍A", "队员A1", "队员A2", "俱乐部A",
                         "队伍B", "队员B1", "队员B2", "俱乐部B", "同俱乐部"])
        for a, b, label in bracket:
            same = "是" if (a.club and b.club and a.club == b.club) else ""
            writer.writerow([label,
                a.name, a.player1, a.player2, a.club,
                b.name, b.player1, b.player2, b.club, same])


def main():
    parser = argparse.ArgumentParser(
        description="淘汰赛对阵表生成器 (16/8/4 强)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python taotaisai.py                        # 默认读取，自动检测队伍数
  python taotaisai.py -i my_teams.csv        # 指定文件
  python taotaisai.py -n 16                  # 指定 16 队
  python taotaisai.py -n 8                   # 指定 8 队
  python taotaisai.py -n 4                   # 指定 4 队
  python taotaisai.py -o bracket.csv         # 输出对阵 CSV
        """
    )
    parser.add_argument("-i", "--input", default="docs/attendance.csv",
                        help="队伍名单 CSV 文件路径 (默认: docs/attendance.csv)")
    parser.add_argument("-n", "--num-teams", type=int, default=None,
                        choices=[16, 8, 4],
                        help="指定队伍数量 16/8/4 (默认: 自动从 CSV 读取)")
    parser.add_argument("-o", "--output", default=None,
                        help="对阵表输出 CSV 路径 (可选)")
    parser.add_argument("--no-resolve", action="store_true",
                        help="不进行同俱乐部错开优化")
    args = parser.parse_args()

    print("掼蛋淘汰赛 — 对阵系统")
    print(f"加载队伍数据: {args.input}")

    try:
        teams = load_teams(args.input)
    except FileNotFoundError:
        print(f"错误: 找不到文件 '{args.input}'", file=sys.stderr)
        sys.exit(1)

    if len(teams) < 2:
        print(f"错误: 至少需要 2 支队伍，当前只有 {len(teams)} 支", file=sys.stderr)
        sys.exit(1)

    print(f"共加载 {len(teams)} 支队伍")

    # 确定参赛队伍数
    if args.num_teams:
        target_count = args.num_teams
    else:
        for n in [16, 8, 4]:
            if len(teams) >= n:
                target_count = n
                break
        else:
            print(f"错误: 队伍数 ({len(teams)}) 不足，至少需要 4 支", file=sys.stderr)
            sys.exit(1)

    # 取积分前 target_count 的队伍
    sorted_teams = sorted(teams, key=lambda t: (-t.score, t.name))
    if len(teams) > target_count:
        print(f"取积分前 {target_count} 支队伍进入淘汰赛")
    selected = sorted_teams[:target_count]

    # 种子排位
    seeded = seed_teams(selected)

    # 根据队伍数选择模板
    if target_count == 16:
        template = BRACKET_16
        title = "淘汰赛 — 16 强对阵表"
    elif target_count == 8:
        template = BRACKET_8
        title = "淘汰赛 — 8 强对阵表"
    elif target_count == 4:
        template = BRACKET_4
        title = "淘汰赛 — 4 强对阵表"
    else:
        print(f"错误: 不支持 {target_count} 支队伍", file=sys.stderr)
        sys.exit(1)

    bracket = build_bracket(seeded, template)

    # 同俱乐部错开优化
    if not args.no_resolve:
        bracket = resolve_same_club(bracket, seeded)

    print_bracket(bracket, target_count, seeded, title)

    if args.output:
        write_bracket_csv(bracket, seeded, args.output)
        print(f"\n对阵表已保存至: {args.output}")

    print(f"\n{'='*70}")
    print(f"  淘汰赛对阵表生成完毕！")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
