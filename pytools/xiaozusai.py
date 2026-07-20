#!/usr/bin/env python3
"""
小组赛 - 单循环排位脚本
参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》

输入：队伍名单 CSV（含当前积分、所属俱乐部/社团）
输出：分组及单循环对阵表

规则：
- 蛇形排位分组（按积分高低）
- 同一俱乐部/社团的队伍尽量分到不同组
- 每组内进行单循环（每两队之间对阵一次）
- 组内对阵轮次安排中，同一俱乐部的队伍尽量错开
"""

import csv
import sys
import argparse
from collections import defaultdict
from dataclasses import dataclass
from itertools import combinations


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


# ── 蛇形分组 ──────────────────────────────────────────────

def snake_distribution(teams: list, num_groups: int, group_size: int) -> list:
    """
    蛇形排位分组：按积分从高到低，蛇形分配到各组。
    完成后做组间交换以尽量将同俱乐部队伍分散到不同组。

    返回: [[Team, ...], ...]  每组为一个 list
    """
    # 按积分降序，同积分按名称排序保证确定性
    sorted_teams = sorted(teams, key=lambda t: (-t.score, t.name))

    groups = [[] for _ in range(num_groups)]

    # 第一步：标准蛇形分配
    for i, team in enumerate(sorted_teams):
        cycle = i // num_groups
        pos_in_cycle = i % num_groups

        if cycle % 2 == 1:
            group_idx = num_groups - 1 - pos_in_cycle
        else:
            group_idx = pos_in_cycle

        groups[group_idx].append(team)

    # 第二步：检查并交换同俱乐部冲突
    # 多次扫描，每次尝试交换一对以消除冲突
    max_swaps = len(teams) * 2
    swaps_done = 0

    for _ in range(max_swaps):
        improved = False
        # 找一对可以交换的、分属不同组的队伍
        # 交换后两边组的同俱乐部冲突都不增加
        for g1 in range(num_groups):
            for g2 in range(g1 + 1, num_groups):
                for i1, t1 in enumerate(groups[g1]):
                    if not t1.club:
                        continue
                    # t1 在 g1 中是否有同俱乐部冲突？
                    t1_has_conflict = any(
                        t.club == t1.club and t.tid != t1.tid
                        for t in groups[g1]
                    )
                    if not t1_has_conflict:
                        continue

                    for i2, t2 in enumerate(groups[g2]):
                        if not t2.club:
                            continue
                        t2_has_conflict = any(
                            t.club == t2.club and t.tid != t2.tid
                            for t in groups[g2]
                        )
                        if not t2_has_conflict:
                            continue

                        # 尝试交换
                        # 检查交换后是否改善
                        new_g1 = groups[g1][:] ; new_g1[i1] = t2
                        new_g2 = groups[g2][:] ; new_g2[i2] = t1

                        def club_conflicts_in(grp):
                            club_count = defaultdict(int)
                            for t in grp:
                                if t.club:
                                    club_count[t.club] += 1
                            return sum(max(0, c - 1) for c in club_count.values())

                        old_conflicts = club_conflicts_in(groups[g1]) + club_conflicts_in(groups[g2])
                        new_conflicts = club_conflicts_in(new_g1) + club_conflicts_in(new_g2)

                        if new_conflicts < old_conflicts:
                            # 执行交换
                            groups[g1][i1], groups[g2][i2] = t2, t1
                            improved = True
                            swaps_done += 1
                            break
                    if improved:
                        break
                if improved:
                    break
            if improved:
                break

        if not improved:
            break

    return groups


# ── 单循环轮次生成（圈圈法 / Circle Method） ──────────

def round_robin_schedule(teams: list) -> list:
    """
    使用圈圈法生成单循环轮次表。
    如果队伍数为奇数，添加一个虚拟"轮空位"。

    返回: [[(Team, Team), ...], ...]  每轮为 list of pairings
    """
    n = len(teams)
    if n < 2:
        return []

    # 奇数队时添加虚拟队（名字为空，实际比赛时轮空）
    names = teams[:]
    has_bye = n % 2 == 1
    if has_bye:
        names.append(None)  # None 表示轮空
        n += 1

    schedule = []
    for rnd in range(n - 1):
        round_pairings = []
        for i in range(n // 2):
            home = names[i]
            away = names[n - 1 - i]
            if home is not None and away is not None:
                round_pairings.append((home, away))
        schedule.append(round_pairings)

        # 旋转（固定第 0 位，其余顺时针旋转）
        last = names.pop()
        names.insert(1, last)

    return schedule


# ── 轮次优化：同俱乐部错开 ──────────────────────────────

def optimize_schedule_by_club(schedule: list) -> list:
    """
    在保持单循环结构的前提下，尽可能让同俱乐部队伍不在同一轮对阵。
    通过调整轮次顺序实现。
    """
    if not schedule:
        return schedule

    # 计算每轮中同俱乐部对阵数量
    def same_club_count(round_pairings):
        count = 0
        for a, b in round_pairings:
            if a.club and b.club and a.club == b.club:
                count += 1
        return count

    # 简单贪心：按同俱乐部对阵数排序（少的轮次优先）
    return sorted(schedule, key=lambda r: same_club_count(r))


# ── 输出 ──────────────────────────────────────────────────

def print_groups_and_schedule(groups: list, group_labels: list):
    """输出分组及对阵表。"""
    print(f"\n{'='*70}")
    print(f"  小组赛 — 单循环对阵表")
    print(f"{'='*70}")

    # 分组概览
    print(f"\n  ── 分组情况 ──")
    print(f"  {'─'*65}")
    for i, (group, label) in enumerate(zip(groups, group_labels)):
        print(f"\n  {label}组 ({len(group)} 队):")
        for t in group:
            club_str = f" [{t.club}]" if t.club else ""
            print(f"    {t.name:20s} {t.player1}/{t.player2:6s}  "
                  f"积分:{t.score:5.1f}{club_str}")

        # 检查是否有同俱乐部问题
        club_counts = defaultdict(list)
        for t in group:
            if t.club:
                club_counts[t.club].append(t.name)
        for club, names in club_counts.items():
            if len(names) > 1:
                print(f"    ⚠ 同俱乐部: [{club}] {' / '.join(names)}")

    # 各组对阵表
    print(f"\n\n  {'='*65}")
    print(f"  各组单循环对阵表")
    print(f"  {'='*65}")

    total_matches = 0

    for i, (group, label) in enumerate(zip(groups, group_labels)):
        print(f"\n  ── {label}组 ──")
        print(f"  {'-'*55}")

        # 生成轮次
        schedule = round_robin_schedule(group)
        schedule = optimize_schedule_by_club(schedule)

        if not schedule:
            print(f"    (队伍数不足，无法生成对阵)")
            continue

        for rnd_idx, round_pairings in enumerate(schedule, 1):
            print(f"\n    第 {rnd_idx} 轮:")
            for a, b in round_pairings:
                club_a = f"[{a.club}]" if a.club else ""
                club_b = f"[{b.club}]" if b.club else ""
                same_club = ""
                if a.club and b.club and a.club == b.club:
                    same_club = " ⚠ 同俱乐部!"
                print(f"      {a.name:14s} ({a.player1}/{a.player2}) {club_a:20s}")
                print(f"        vs {b.name:14s} ({b.player1}/{b.player2}) {club_b:20s}{same_club}")
                total_matches += 1

    # 统计
    print(f"\n\n  {'─'*65}")
    print(f"  统计:")
    print(f"  总组数:    {len(groups)}")
    print(f"  总队伍数:  {sum(len(g) for g in groups)}")
    print(f"  总对阵数:  {total_matches}")
    print(f"  每组队伍:  {len(groups[0]) if groups else 0} 队/组")

    # 计算同俱乐部对阵
    total_same_club = 0
    for group in groups:
        schedule = round_robin_schedule(group)
        for rnd in schedule:
            for a, b in rnd:
                if a.club and b.club and a.club == b.club:
                    total_same_club += 1
    if total_same_club > 0:
        print(f"  ⚠ 同俱乐部对阵: {total_same_club} 场（已尽力避免）")
    else:
        print(f"  同俱乐部对阵: 0 场 ✓")


def write_groups_csv(groups: list, group_labels: list, filepath: str):
    """将分组结果输出为 CSV 文件。"""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["组别", "队伍名称", "队员1", "队员2", "所属俱乐部", "积分"])
        for group, label in zip(groups, group_labels):
            for t in group:
                writer.writerow([label, t.name, t.player1, t.player2, t.club, f"{t.score:.1f}"])


def write_schedule_csv(groups: list, group_labels: list, filepath: str):
    """将完整赛程输出为 CSV 文件。"""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["组别", "轮次", "队伍A", "队员A1", "队员A2", "俱乐部A",
                         "队伍B", "队员B1", "队员B2", "俱乐部B", "同俱乐部"])
        for group, label in zip(groups, group_labels):
            schedule = round_robin_schedule(group)
            schedule = optimize_schedule_by_club(schedule)
            for rnd_idx, rnd in enumerate(schedule, 1):
                for a, b in rnd:
                    same = "是" if (a.club and b.club and a.club == b.club) else ""
                    writer.writerow([label, rnd_idx,
                        a.name, a.player1, a.player2, a.club,
                        b.name, b.player1, b.player2, b.club, same])


def main():
    parser = argparse.ArgumentParser(
        description="小组赛单循环对阵表生成器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python xiaozusai.py                              # 默认 32 队分 8 组
  python xiaozusai.py -i my_teams.csv -g 4 -s 4    # 自定义
  python xiaozusai.py -g 2 -s 4                    # 8 队分 2 组，每组 4 队
  python xiaozusai.py -o output_prefix             # 输出 CSV 文件
        """
    )
    parser.add_argument("-i", "--input", default="docs/attendance.csv",
                        help="队伍名单 CSV 文件路径 (默认: docs/attendance.csv)")
    parser.add_argument("-g", "--groups", type=int, default=None,
                        help="分组数量 (默认: 自动计算，使每组 4 队)")
    parser.add_argument("-s", "--group-size", type=int, default=4,
                        help="每组队伍数 (默认: 4)")
    parser.add_argument("-o", "--output", default=None,
                        help="输出 CSV 前缀 (可选，生成 {prefix}_groups.csv 和 {prefix}_schedule.csv)")
    args = parser.parse_args()

    print("掼蛋小组赛 — 单循环对阵系统")
    print(f"加载队伍数据: {args.input}")

    try:
        teams = load_teams(args.input)
    except FileNotFoundError:
        print(f"错误: 找不到文件 '{args.input}'", file=sys.stderr)
        sys.exit(1)

    if len(teams) < 3:
        print(f"错误: 至少需要 3 支队伍进行小组赛，当前只有 {len(teams)} 支", file=sys.stderr)
        sys.exit(1)

    print(f"共加载 {len(teams)} 支队伍")

    # 计算分组
    group_size = args.group_size
    if args.groups:
        num_groups = args.groups
    else:
        num_groups = max(1, len(teams) // group_size)

    # 取前 num_groups * group_size 支队伍
    sorted_teams = sorted(teams, key=lambda t: t.score, reverse=True)
    max_teams = num_groups * group_size
    if len(teams) > max_teams:
        print(f"注意: 队伍数 ({len(teams)}) 超过 {num_groups}×{group_size}={max_teams}，"
              f"将取积分前 {max_teams} 支队伍")
        selected_teams = sorted_teams[:max_teams]
    elif len(teams) < max_teams:
        print(f"注意: 队伍数 ({len(teams)}) 不足 {num_groups}×{group_size}={max_teams}，"
              f"调整为 {num_groups} 组，每组 {len(teams) // num_groups} 队")
        group_size = len(teams) // num_groups
        selected_teams = teams
    else:
        selected_teams = teams

    # 分组
    groups = snake_distribution(selected_teams, num_groups, group_size)

    # 生成组别标签
    group_labels = [chr(65 + i) for i in range(num_groups)]  # A, B, C, ...

    # 输出
    print_groups_and_schedule(groups, group_labels)

    if args.output:
        write_groups_csv(groups, group_labels, f"{args.output}_groups.csv")
        write_schedule_csv(groups, group_labels, f"{args.output}_schedule.csv")
        print(f"\n分组已保存至: {args.output}_groups.csv")
        print(f"赛程已保存至: {args.output}_schedule.csv")

    print(f"\n{'='*70}")
    print(f"  小组赛对阵表生成完毕！")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
