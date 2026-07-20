#!/usr/bin/env python3
"""
海选赛 - 瑞士移位制配对脚本
参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》

输入：队伍名单 CSV（含当前积分、所属俱乐部/社团）
输出：下一轮的瑞士移位制排位对阵表

规则：
- 按当前积分从高到低排序
- 同积分段内优先配对，尽量避免已对阵过的队伍再次相遇
- 同一俱乐部/社团的队伍尽量错开
- 奇数队伍时末位轮空
"""

import csv
import sys
import argparse
from collections import defaultdict
from dataclasses import dataclass, field


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
    score: float = 0.0          # 当前积分（场分）
    net_small: int = 0           # 净积小分
    cum_small: int = 0           # 累积小分
    opponents: set = field(default_factory=set)  # 已对阵过的队伍 ID 集合
    rounds_played: int = 0
    bye_count: int = 0

    def display(self) -> str:
        club_str = f" [{self.club}]" if self.club else ""
        return f"{self.name}({self.player1}/{self.player2}){club_str}"


# ── CSV 读取 ──────────────────────────────────────────────

def load_teams(csv_path: str) -> list:
    """从 CSV 读取队伍名单，返回按原始顺序的列表。"""
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


# ── 排名 ──────────────────────────────────────────────────

def sort_by_ranking(teams: list) -> list:
    """
    按积分降序 → 净积小分降序 → 累积小分降序 排序。
    """
    return sorted(teams, key=lambda t: (t.score, t.net_small, t.cum_small), reverse=True)


# ── 瑞士移位制配对 ─────────────────────────────────────

def swiss_pairing(teams: list) -> tuple:
    """
    瑞士移位制配对：同积分段优先配对，避免已对阵过的队伍相遇，
    同一俱乐部尽量错开。

    返回 (pairings, bye_team)
    - pairings: [(team_a, team_b), ...]
    - bye_team: 轮空队伍 或 None
    """
    sorted_teams = sort_by_ranking(teams)
    paired = set()
    pairings = []
    bye_team = None

    # 按积分分组
    score_groups = defaultdict(list)
    for t in sorted_teams:
        score_groups[t.score].append(t)

    score_levels = sorted(score_groups.keys(), reverse=True)

    # ── 第一阶段：组内配对 ──
    # 每组的剩余队伍跨组处理
    residual_by_score = {}

    for score in score_levels:
        group = [t for t in score_groups[score] if t.tid not in paired]

        # 组内贪心配对，优先选择不同俱乐部的对手
        while len(group) >= 2:
            a = group[0]
            # 在同分数组中找最佳对手
            # 优先级：1) 未对阵过 2) 不同俱乐部 3) 序号接近
            best = None
            best_idx = None
            best_priority = (-1, -1)  # (can_play, same_club penalty)

            for idx, b in enumerate(group[1:], 1):
                can_play = 0 if b.tid not in a.opponents else 1  # 0 = 可对阵
                same_club = 0 if a.club and a.club == b.club else 1  # 1 = 不同俱乐部
                # 优先级元组：可对阵优先（遇到已对阵过的排最后），不同俱乐部优先
                priority = (can_play, same_club)
                if priority > best_priority:
                    best_priority = priority
                    best = b
                    best_idx = idx

            # 如果最优对手也已经被对阵过且没有其他选择，允许重赛
            if best is None:
                best = group[1]
                best_idx = 1

            pairings.append((a, best))
            paired.add(a.tid)
            paired.add(best.tid)
            group = [t for t in group if t.tid not in paired]

        residual_by_score[score] = group

    # ── 第二阶段：跨积分段配对 ──
    # 收集所有剩余未配对队伍，按积分降序
    all_residual = []
    for score in score_levels:
        all_residual.extend(residual_by_score.get(score, []))

    # 跨积分段贪心配对
    while len(all_residual) >= 2:
        a = all_residual[0]
        best = None
        best_idx = None
        best_priority = (-1, -1, float("inf"))  # (can_play, same_club, score_diff)

        for idx, b in enumerate(all_residual[1:], 1):
            can_play = 0 if b.tid not in a.opponents else 1
            same_club = 0 if a.club and a.club == b.club else 1
            score_diff = abs(a.score - b.score)  # 积分差距越小越好
            priority = (can_play, same_club, -score_diff)
            if priority > best_priority:
                best_priority = priority
                best = b
                best_idx = idx

        if best is None:
            best = all_residual[1]
            best_idx = 1

        pairings.append((a, best))
        paired.add(a.tid)
        paired.add(best.tid)
        all_residual = [t for t in all_residual if t.tid not in paired]

    # ── 第三阶段：确认轮空 ──
    unpaired = [t for t in sorted_teams if t.tid not in paired]
    if len(unpaired) == 1:
        bye_team = unpaired[0]

    return pairings, bye_team


# ── 输出 ──────────────────────────────────────────────────

def print_pairings(pairings: list, bye_team, round_num: int, all_teams: list):
    """格式化输出本轮对阵表。"""
    print(f"\n{'='*70}")
    print(f"  瑞士移位制 — 第 {round_num} 轮对阵表")
    print(f"{'='*70}")

    # 输出积分排名
    ranked = sort_by_ranking(all_teams)
    print(f"\n  当前排名 (积分 → 净积小分 → 累积小分):")
    print(f"  {'─'*65}")
    for i, t in enumerate(ranked):
        club_str = f" [{t.club}]" if t.club else ""
        print(f"  {i+1:3d}. {t.name:20s} {t.player1}/{t.player2:6s}  "
              f"积分:{t.score:5.1f}  净小分:{t.net_small:+4d}  累小分:{t.cum_small:4d}{club_str}")

    # 输出对阵
    print(f"\n  ── 第 {round_num} 轮对阵 ──")
    print(f"  {'─'*65}")
    table_num = 1
    for a, b in pairings:
        club_a = f"[{a.club}]" if a.club else ""
        club_b = f"[{b.club}]" if b.club else ""
        same_club_warn = " ⚠ 同俱乐部!" if (a.club and b.club and a.club == b.club) else ""
        print(f"  桌{table_num:2d}: {a.name:16s} ({a.player1}/{a.player2}) {club_a:20s}")
        print(f"        vs {b.name:16s} ({b.player1}/{b.player2}) {club_b:20s}{same_club_warn}")
        table_num += 1

    if bye_team:
        club_str = f"[{bye_team.club}]" if bye_team.club else ""
        print(f"\n  轮空: {bye_team.name} ({bye_team.player1}/{bye_team.player2}) {club_str}")
        print(f"     → 轮空获 3 积分")

    # 统计
    print(f"\n  ── 统计 ──")
    print(f"  总队伍数: {len(all_teams)}")
    print(f"  对阵数:   {len(pairings)}")
    print(f"  轮空:     {'是' if bye_team else '否'}")
    same_club_pairs = sum(1 for a, b in pairings if a.club and b.club and a.club == b.club)
    if same_club_pairs > 0:
        print(f"  ⚠ 同俱乐部对阵: {same_club_pairs} 组（已尽力避免）")
    else:
        print(f"  同俱乐部对阵: 0 组 ✓")


def write_pairings_csv(pairings: list, bye_team, round_num: int, filepath: str):
    """将对阵表输出为 CSV 文件。"""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["桌号", "队伍A", "队员A1", "队员A2", "俱乐部A",
                         "队伍B", "队员B1", "队员B2", "俱乐部B", "同俱乐部"])
        for idx, (a, b) in enumerate(pairings, 1):
            same = "是" if (a.club and b.club and a.club == b.club) else ""
            writer.writerow([idx,
                a.name, a.player1, a.player2, a.club,
                b.name, b.player1, b.player2, b.club, same])
        if bye_team:
            writer.writerow(["轮空", bye_team.name, bye_team.player1, bye_team.player2,
                            bye_team.club, "", "", "", "", ""])


def main():
    parser = argparse.ArgumentParser(
        description="瑞士移位制海选赛配对生成器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python haixuansai.py                           # 默认读取 docs/attendance.csv
  python haixuansai.py -i my_teams.csv -r 3      # 指定文件和轮次
  python haixuansai.py -o pairings.csv           # 输出对阵 CSV
        """
    )
    parser.add_argument("-i", "--input", default="docs/attendance.csv",
                        help="队伍名单 CSV 文件路径 (默认: docs/attendance.csv)")
    parser.add_argument("-r", "--round", type=int, default=1,
                        help="当前轮次编号 (默认: 1)")
    parser.add_argument("-o", "--output", default=None,
                        help="对阵表输出 CSV 路径 (可选)")
    args = parser.parse_args()

    print("掼蛋海选赛 — 瑞士移位制配对系统")
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

    # 生成配对
    pairings, bye_team = swiss_pairing(teams)

    # 输出
    print_pairings(pairings, bye_team, args.round, teams)

    if args.output:
        write_pairings_csv(pairings, bye_team, args.round, args.output)
        print(f"\n对阵表已保存至: {args.output}")

    print(f"\n{'='*70}")
    print(f"  对阵表生成完毕！")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
