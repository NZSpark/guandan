#!/usr/bin/env python3
"""
掼蛋锦标赛仿真脚本 — 完整赛程模拟系统
参照南山杯 Aotearoa 掼蛋大赛指南（2026）及《掼蛋（国家）竞赛规则（2017版）》

赛程：海选赛(瑞士移位制) → 小组赛(单循环) → 淘汰赛 → 决赛
调用 haixuansai.py / xiaozusai.py / taotaisai.py 完成各阶段排位对阵。

中间输出文件（output/ 目录）：
  haixuansai_round1.csv  ~ haixuansai_round4.csv   海选赛各轮后积分（可作下轮输入）
  haixuansai_pairings_round1.csv ~ ...              海选赛各轮对阵表（供人工核查）
  xiaozusai_groups.csv                              小组赛分组
  xiaozusai_schedule.csv                            小组赛完整赛程
  xiaozusai_results.csv                             小组赛结果（含积分）
  taotaisai_bracket.csv                             淘汰赛对阵表
  taotaisai_results.csv                             淘汰赛最终结果
"""

import csv
import random
import os
import sys
from dataclasses import dataclass, field
from typing import Optional
from collections import defaultdict
from types import SimpleNamespace

# 确保当前目录在 path 中，以便导入同目录的子模块
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import haixuansai
import xiaozusai
import taotaisai

# ── 输出目录 ──────────────────────────────────────────────

OUTPUT_DIR = "output"


# ── 级数体系 ──────────────────────────────────────────────

LEVEL_NAMES = ["2","3","4","5","6","7","8","9","10","J","Q","K","A"]
LEVEL_TO_INT = {name: i+2 for i, name in enumerate(LEVEL_NAMES)}  # 2..14
INT_TO_LEVEL = {v: k for k, v in LEVEL_TO_INT.items()}

def level_int(name: str) -> int:
    return LEVEL_TO_INT[name]

def level_name(val: int) -> str:
    return INT_TO_LEVEL.get(val, "?")

def is_ace(name: str) -> bool:
    return name == "A"


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

    # 赛事统计
    field_score: float = 0.0         # 总场分
    total_net_small: int = 0         # 总净积小分
    total_cum_small: int = 0         # 总累积小分
    opponents: set = field(default_factory=set)  # 对阵过的队伍ID
    match_results: dict = field(default_factory=dict)  # tid -> "W"/"L"/"D"
    rounds_played: int = 0
    bye_count: int = 0

    def reset_stats(self):
        self.field_score = 0.0
        self.total_net_small = 0
        self.total_cum_small = 0
        self.opponents = set()
        self.match_results = {}
        self.rounds_played = 0
        self.bye_count = 0

    def display(self) -> str:
        return f"{self.name}({self.player1}/{self.player2})"


# ── 适配器：将 simulate Team 转为子脚本兼容的 SimpleNamespace ──

def team_to_adapter(t: Team) -> SimpleNamespace:
    """转换为子脚本函数可用的简易对象。"""
    return SimpleNamespace(
        tid=t.tid,
        name=t.name,
        player1=t.player1,
        gender1=t.gender1,
        player2=t.player2,
        gender2=t.gender2,
        club=t.club,
        score=t.field_score,          # haixuansai/xiaozusai/taotaisai 都用 .score
        net_small=t.total_net_small,  # haixuansai 破同分用
        cum_small=t.total_cum_small,  # haixuansai 破同分用
        opponents=t.opponents,        # haixuansai 避免重复对阵用
    )


def adapter_to_team(a, teams_dict: dict) -> Team:
    """从适配器对象找回原始 Team 对象。"""
    return teams_dict[a.tid]


# ── 比赛级别模拟 ─────────────────────────────────────────

def simulate_levels(team_a: Team, team_b: Team, time_limit: int = 70,
                    rng: random.Random = None) -> tuple:
    """
    模拟一场掼蛋比赛，返回 (team_a_final_level, team_b_final_level)。
    
    模拟逻辑：
    - 双方从2开始打，在限时内尽可能升级
    - 每副牌结果概率决定级数推进速度
    - 过A视为14
    """
    if rng is None:
        rng = random

    # 队伍基础实力（基于队名的哈希，同一俱乐部有微弱协同）
    def team_strength(t: Team) -> float:
        base = hash(t.name) % 100 / 100.0
        # 俱乐部加成
        if t.club:
            base += hash(t.club) % 5 / 100.0
        # 性别多样性微调
        if t.gender1 != t.gender2:
            base += 0.05
        return base

    strength_a = team_strength(team_a)
    strength_b = team_strength(team_b)
    diff = strength_a - strength_b

    # 比赛中的升级模拟
    level_a = 2   # 当前级数
    level_b = 2
    max_hands = time_limit // 5  # 平均每副牌5分钟
    hands_played = 0

    # Ace尝试计数
    ace_fails_a = 0
    ace_fails_b = 0

    for _ in range(max_hands):
        hands_played += 1
        # 这一副牌的胜负
        roll = rng.random() + diff * 0.3
        if roll > 0.7 + diff * 0.2:
            result = "double_a"
        elif roll > 0.55:
            result = "win_a"
        elif roll > 0.48:
            result = "narrow_a"
        elif roll > 0.42:
            result = "draw"
        elif roll > 0.35:
            result = "narrow_b"
        elif roll > 0.2 + diff * 0.15:
            result = "win_b"
        else:
            result = "double_b"

        # 根据结果升级
        if result == "double_a":
            level_a += 3
        elif result == "win_a":
            level_a += 2
        elif result == "narrow_a":
            level_a += 1
        elif result == "double_b":
            level_b += 3
        elif result == "win_b":
            level_b += 2
        elif result == "narrow_b":
            level_b += 1

        # 过A检查
        if level_a >= 14:
            if result in ("win_a", "double_a", "narrow_a"):
                if result in ("win_a", "double_a"):
                    level_a = 14
                    break
                else:
                    level_a = 14
                    ace_fails_a += 1
                    if ace_fails_a >= 3:
                        level_a = 2
                        ace_fails_a = 0
            else:
                ace_fails_a += 1
                if ace_fails_a >= 3:
                    level_a = 2
                    ace_fails_a = 0

        if level_b >= 14:
            if result in ("win_b", "double_b", "narrow_b"):
                if result in ("win_b", "double_b"):
                    level_b = 14
                    break
                else:
                    level_b = 14
                    ace_fails_b += 1
                    if ace_fails_b >= 3:
                        level_b = 2
                        ace_fails_b = 0
            else:
                ace_fails_b += 1
                if ace_fails_b >= 3:
                    level_b = 2
                    ace_fails_b = 0

    # 确保A打完且有结果
    if level_a >= 14 and level_b < 14:
        level_a = 14
    elif level_b >= 14 and level_a < 14:
        level_b = 14

    final_a = min(level_a, 14)
    final_b = min(level_b, 14)

    return (INT_TO_LEVEL[final_a], INT_TO_LEVEL[final_b])


# ── 计分 & 赛果 ──────────────────────────────────────────

FIELD_WIN = 3.0
FIELD_DRAW = 2.0
FIELD_LOSE = 1.0
FIELD_ABSENT = 0.0
FIELD_BYE = 3.0


def match_result(la: str, lb: str) -> tuple:
    """返回 (team_a结果, team_b结果, net_a, net_b, cum_a, cum_b)"""
    ia = level_int(la)
    ib = level_int(lb)
    net_a = ia - ib
    net_b = ib - ia
    cum_a = (ia - 2) + (1 if is_ace(la) else 0)
    cum_b = (ib - 2) + (1 if is_ace(lb) else 0)

    if ia > ib:
        return ("W", "L", net_a, net_b, cum_a, cum_b)
    elif ib > ia:
        return ("L", "W", net_a, net_b, cum_a, cum_b)
    else:
        return ("D", "D", 0, 0, cum_a, cum_b)


def field_score(result: str) -> float:
    if result == "W":
        return FIELD_WIN
    elif result == "D":
        return FIELD_DRAW
    elif result == "L":
        return FIELD_LOSE
    else:
        return FIELD_ABSENT


def play_match(team_a: Team, team_b: Team, time_limit: int = 70,
               rng: random.Random = None) -> tuple:
    """
    模拟一场比赛，返回 (结果A, 结果B, levelA, levelB, netA, netB, cumA, cumB)
    并更新队伍统计。
    """
    la, lb = simulate_levels(team_a, team_b, time_limit, rng)
    ra, rb, net_a, net_b, cum_a, cum_b = match_result(la, lb)

    team_a.field_score += field_score(ra)
    team_b.field_score += field_score(rb)
    team_a.total_net_small += net_a
    team_b.total_net_small += net_b
    team_a.total_cum_small += cum_a
    team_b.total_cum_small += cum_b
    team_a.opponents.add(team_b.tid)
    team_b.opponents.add(team_a.tid)
    team_a.match_results[team_b.tid] = ra
    team_b.match_results[team_a.tid] = rb
    team_a.rounds_played += 1
    team_b.rounds_played += 1

    return (ra, rb, la, lb, net_a, net_b, cum_a, cum_b)


def give_bye(team: Team):
    """给轮空队伍分配分数"""
    team.field_score += FIELD_BYE
    team.rounds_played += 1
    team.bye_count += 1


# ── 排名比较 ─────────────────────────────────────────────

def tiebreak_sort(teams: list) -> list:
    """按总场分→相互胜负→净积小分→累积小分排序（降序）"""
    # 先按场分分组
    score_groups = defaultdict(list)
    for t in teams:
        score_groups[t.field_score].append(t)

    result = []
    for score in sorted(score_groups.keys(), reverse=True):
        group = score_groups[score]
        if len(group) == 1:
            result.extend(group)
        else:
            resolved = resolve_ties(group)
            result.extend(resolved)
    return result


def resolve_ties(group: list) -> list:
    """对同分队破同分"""
    if len(group) <= 1:
        return group

    if len(group) == 2:
        a, b = group
        ra = a.match_results.get(b.tid)
        rb = b.match_results.get(a.tid)
        if ra == "W" and rb == "L":
            return [a, b]
        elif rb == "W" and ra == "L":
            return [b, a]

    sorted_by_net = sorted(group, key=lambda t: t.total_net_small, reverse=True)
    net_groups = defaultdict(list)
    for t in sorted_by_net:
        net_groups[t.total_net_small].append(t)

    result = []
    for net_val in sorted(net_groups.keys(), reverse=True):
        sub = net_groups[net_val]
        if len(sub) == 1:
            result.extend(sub)
        else:
            result.extend(sorted(sub, key=lambda t: t.total_cum_small, reverse=True))
    return result


# ── CSV 读写工具 ─────────────────────────────────────────

def ensure_output_dir():
    """确保输出目录存在。"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)


def load_teams(csv_path: str) -> dict:
    """从 CSV 读取队伍名单。"""
    teams = {}
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
                field_score=score,
            )
            teams[i] = team
    return teams


def write_teams_csv(teams_list: list, filepath: str, extra_cols: list = None):
    """
    将队伍列表输出为 CSV（兼容 attendance.csv 格式）。
    额外列: [(header, value_fn), ...]，value_fn(t) -> str
    """
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        headers = ["队伍名称", "队员1", "性别1", "队员2", "性别2", "所属俱乐部/社团", "当前积分"]
        if extra_cols:
            for h, _ in extra_cols:
                headers.append(h)
        writer.writerow(headers)
        for t in teams_list:
            row = [t.name, t.player1, t.gender1, t.player2, t.gender2, t.club, f"{t.field_score:.1f}"]
            if extra_cols:
                for _, fn in extra_cols:
                    row.append(fn(t))
            writer.writerow(row)
    return full_path


def write_pairings_csv(pairings: list, bye_team, filepath: str):
    """将对阵表输出为 CSV。"""
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
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
    return full_path


def write_match_log_csv(matches: list, filepath: str):
    """将比赛结果输出为 CSV。
    matches: [(a, b, ra, rb, la, lb), ...]
    """
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["队伍A", "队伍B", "结果A", "级数A", "结果B", "级数B", "俱乐部A", "俱乐部B"])
        for a, b, ra, rb, la, lb in matches:
            writer.writerow([a.name, b.name, ra, la, rb, lb, a.club, b.club])
    return full_path


# ═══════════════════════════════════════════════════════════
#  阶段一：海选赛（瑞士移位制）
# ═══════════════════════════════════════════════════════════

def run_haixuansai(teams: dict, num_rounds: int = 4, time_limit: int = 70,
                   seed: int = 42, top_n: int = 32) -> list:
    """
    瑞士移位制海选赛。
    每轮调用 haixuansai.swiss_pairing() 生成对阵。
    返回 top_n 晋级队伍列表。
    """
    rng = random.Random(seed)
    active_teams = list(teams.values())

    # 重置统计
    for t in active_teams:
        t.reset_stats()

    print(f"\n{'='*70}")
    print(f"  阶段一：海选赛（瑞士移位制）")
    print(f"  {len(active_teams)} 支队伍，{num_rounds} 轮，每局限时 {time_limit} 分钟")
    print(f"{'='*70}")

    for rnd in range(1, num_rounds + 1):
        print(f"\n{'─'*70}")
        print(f"  第 {rnd} 轮")
        print(f"{'─'*70}")

        # 调用 haixuansai 生成配对
        adapters = [team_to_adapter(t) for t in active_teams]
        pairings, bye_adapter = haixuansai.swiss_pairing(adapters)

        # 转换回原始 Team 对象
        sim_pairings = [(adapter_to_team(a, teams), adapter_to_team(b, teams))
                        for a, b in pairings]
        bye_team = adapter_to_team(bye_adapter, teams) if bye_adapter else None

        # 保存对阵表 CSV（供人工核查）
        pairings_file = f"haixuansai_pairings_round{rnd}.csv"
        write_pairings_csv(sim_pairings, bye_team, pairings_file)
        print(f"  对阵表已保存: {OUTPUT_DIR}/{pairings_file}")

        # 模拟比赛
        match_log = []
        for (a, b) in sim_pairings:
            ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)
            match_log.append((a, b, ra, rb, la, lb))
            same_club = " ⚠同俱乐部!" if (a.club and b.club and a.club == b.club) else ""
            print(f"  {a.display():28s} vs {b.display():28s}  "
                  f"{la}-{lb}  [{ra}/{rb}]{same_club}")

        if bye_team:
            give_bye(bye_team)
            print(f"  [轮空] {bye_team.display()} → 自动获 3 分")

        # 每轮后显示排名
        ranked = tiebreak_sort(active_teams)
        print(f"\n  第 {rnd} 轮后排名 (前10):")
        for i, t in enumerate(ranked[:10]):
            print(f"    {i+1:2d}. {t.display():28s}  场分:{t.field_score:.0f}  "
                  f"净积:{t.total_net_small:+d}  累积:{t.total_cum_small}")

        # 保存本轮积分 CSV（作为下一轮输入）
        score_file = f"haixuansai_round{rnd}.csv"
        write_teams_csv(active_teams, score_file, extra_cols=[
            ("净积小分", lambda t: str(t.total_net_small)),
            ("累积小分", lambda t: str(t.total_cum_small)),
        ])
        print(f"  积分已保存: {OUTPUT_DIR}/{score_file}")

        # 保存本轮比赛结果
        match_log_file = f"haixuansai_matches_round{rnd}.csv"
        write_match_log_csv(match_log, match_log_file)

    final_ranking = tiebreak_sort(active_teams)
    top = final_ranking[:top_n]

    print(f"\n{'─'*70}")
    print(f"  海选赛最终排名 ({top_n} 强晋级):")
    print(f"{'─'*70}")
    for i, t in enumerate(final_ranking):
        marker = "→ 晋级小组赛" if i < top_n else ""
        print(f"  {i+1:2d}. {t.display():28s}  场分:{t.field_score:.0f}  "
              f"净积:{t.total_net_small:+d}  累积:{t.total_cum_small}  {marker}")

    # 保存海选赛最终成绩
    write_teams_csv(final_ranking, "haixuansai_final.csv", extra_cols=[
        ("净积小分", lambda t: str(t.total_net_small)),
        ("累积小分", lambda t: str(t.total_cum_small)),
    ])
    print(f"\n  海选赛最终成绩已保存: {OUTPUT_DIR}/haixuansai_final.csv")

    return top


# ═══════════════════════════════════════════════════════════
#  阶段二：小组赛（单循环）
# ═══════════════════════════════════════════════════════════

def run_xiaozusai(teams: dict, top_teams: list, num_groups: int = 8,
                  group_size: int = 4, time_limit: int = 70,
                  seed: int = 7) -> list:
    """
    小组赛单循环。
    调用 xiaozusai.snake_distribution() 分组，
    调用 xiaozusai.round_robin_schedule() 生成赛程。
    返回 top16 出线队伍列表。
    """
    rng = random.Random(seed)

    # 重置统计数据
    for t in top_teams:
        t.reset_stats()

    print(f"\n{'='*70}")
    print(f"  阶段二：小组赛（单循环）")
    print(f"  {len(top_teams)} 队分 {num_groups} 组，每组 {group_size} 队，每局限时 {time_limit} 分钟")
    print(f"{'='*70}")

    # 调用 xiaozusai 蛇形分组
    adapters = [team_to_adapter(t) for t in top_teams]
    groups_adapters = xiaozusai.snake_distribution(adapters, num_groups, group_size)

    # 转换回原始 Team 对象
    groups = [[adapter_to_team(a, teams) for a in grp] for grp in groups_adapters]
    group_labels = [chr(65 + i) for i in range(num_groups)]

    # 保存分组 CSV
    _write_groups_to_csv(groups, group_labels, "xiaozusai_groups.csv")
    print(f"\n  分组已保存: {OUTPUT_DIR}/xiaozusai_groups.csv")

    # 显示分组
    print(f"\n  分组情况:")
    for i, (group, label) in enumerate(zip(groups, group_labels)):
        names = " | ".join(t.display() for t in group)
        club_info = ""
        # 检查同俱乐部分布
        club_counts = defaultdict(list)
        for t in group:
            if t.club:
                club_counts[t.club].append(t.name)
        warnings = []
        for club, cnames in club_counts.items():
            if len(cnames) > 1:
                warnings.append(f"[{club}] {'/'.join(cnames)}")
        if warnings:
            club_info = "  ⚠ " + "  ".join(warnings)
        print(f"    {label}组: {names}{club_info}")

    # 每组进行单循环
    all_matches = []  # 收集所有比赛用于 CSV 输出
    group_winners = []
    group_runners_up = []

    for g_idx, (group, label) in enumerate(zip(groups, group_labels)):
        print(f"\n  ── {label}组 ──")

        # 调用 xiaozusai 生成赛程
        group_adapters = [team_to_adapter(t) for t in group]
        schedule = xiaozusai.round_robin_schedule(group_adapters)
        schedule = xiaozusai.optimize_schedule_by_club(schedule)

        # 模拟比赛
        for rnd_idx, round_pairings in enumerate(schedule, 1):
            for a_adapter, b_adapter in round_pairings:
                a = adapter_to_team(a_adapter, teams)
                b = adapter_to_team(b_adapter, teams)
                ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)
                all_matches.append((a, b, ra, rb, la, lb, label, rnd_idx))
                same_club = " ⚠同俱乐部!" if (a.club and b.club and a.club == b.club) else ""
                print(f"    轮{rnd_idx}: {a.display():24s} vs {b.display():24s}  "
                      f"{la}-{lb}  [{ra}/{rb}]{same_club}")

        # 组内排名
        ranked = tiebreak_sort(group)
        print(f"\n    {label}组排名:")
        for i, t in enumerate(ranked):
            qual = "→ 晋级" if i < 2 else ""
            print(f"      {i+1}. {t.display():24s}  场分:{t.field_score:.0f}  "
                  f"净积:{t.total_net_small:+d}  累积:{t.total_cum_small}  {qual}")

        group_winners.append(ranked[0])
        group_runners_up.append(ranked[1])

        # 保存每组详细结果
        write_teams_csv(ranked, f"xiaozusai_组{label}_results.csv", extra_cols=[
            ("净积小分", lambda t: str(t.total_net_small)),
            ("累积小分", lambda t: str(t.total_cum_small)),
        ])

    # 保存完整的比赛日志
    _write_group_match_log(all_matches, "xiaozusai_matches.csv")

    # 16强：小组第一 + 小组第二
    top16 = group_winners + group_runners_up

    print(f"\n{'─'*70}")
    print(f"  小组赛出线 16 强:")
    print(f"{'─'*70}")
    for i, t in enumerate(top16):
        src = f"{chr(65 + i) if i < 8 else chr(65 + i - 8)}组第{'一' if i < 8 else '二'}"
        print(f"  {i+1:2d}. {t.display():24s}  [{src}]  场分:{t.field_score:.0f}")

    # 保存小组赛结果和出线名单
    write_teams_csv(top16, "xiaozusai_top16.csv", extra_cols=[
        ("净积小分", lambda t: str(t.total_net_small)),
        ("累积小分", lambda t: str(t.total_cum_small)),
    ])
    print(f"\n  出线名单已保存: {OUTPUT_DIR}/xiaozusai_top16.csv")

    return top16


def _write_groups_to_csv(groups: list, labels: list, filepath: str):
    """分组结果→CSV"""
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["组别", "队伍名称", "队员1", "队员2", "所属俱乐部", "积分"])
        for group, label in zip(groups, labels):
            for t in group:
                writer.writerow([label, t.name, t.player1, t.player2, t.club,
                                 f"{t.field_score:.1f}"])


def _write_group_match_log(matches: list, filepath: str):
    """小组赛全部比赛→CSV"""
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["组别", "轮次", "队伍A", "队伍B", "结果A", "级数A", "结果B", "级数B",
                         "俱乐部A", "俱乐部B"])
        for a, b, ra, rb, la, lb, grp_label, rnd in matches:
            writer.writerow([grp_label, rnd, a.name, b.name, ra, la, rb, lb, a.club, b.club])


# ═══════════════════════════════════════════════════════════
#  阶段三：淘汰赛
# ═══════════════════════════════════════════════════════════

def run_taotaisai(teams: dict, top16: list, time_limit: int = 120,
                  seed: int = 13) -> list:
    """
    单败淘汰赛。
    调用 taotaisai 生成对阵 bracket，然后逐轮模拟。
    返回最终排名列表。
    """
    rng = random.Random(seed)

    # 重置参赛队伍统计
    for t in top16:
        t.reset_stats()

    print(f"\n{'='*70}")
    print(f"  阶段三：淘汰赛（16 强单败淘汰）")
    print(f"  {len(top16)} 队，每局限时 {time_limit} 分钟")
    print(f"{'='*70}")

    # 调用 taotaisai 生成对阵 bracket
    adapters = [team_to_adapter(t) for t in top16]
    seeded = taotaisai.seed_teams(adapters)
    bracket = taotaisai.build_bracket(seeded, taotaisai.BRACKET_16)
    bracket = taotaisai.resolve_same_club(bracket, seeded)

    # 转换回原始 Team
    sim_bracket = []
    for a_adp, b_adp, label in bracket:
        sim_bracket.append((adapter_to_team(a_adp, teams),
                            adapter_to_team(b_adp, teams), label))

    # 保存对阵表 CSV
    _write_bracket_csv(sim_bracket, "taotaisai_bracket.csv")
    print(f"\n  对阵表已保存: {OUTPUT_DIR}/taotaisai_bracket.csv")

    # 显示对阵表
    print(f"\n  ── 淘汰赛对阵 ──")
    for a, b, label in sim_bracket:
        same = " ⚠同俱乐部!" if (a.club and b.club and a.club == b.club) else ""
        print(f"  {label}: {a.display():20s} vs {b.display():20s}{same}")

    # ── 1/8 决赛 ──
    print(f"\n  ── 1/8 决赛 ──")
    quarter_results = []
    quarter_losers = []
    r16_match_log = []

    for idx, (a, b, label) in enumerate(sim_bracket):
        ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)
        r16_match_log.append((a, b, ra, rb, la, lb, "1/8", idx + 1))

        # 平局加赛
        if ra == "D":
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  平局！加赛...", end=" ")
            extra_roll = rng.random()
            if extra_roll > 0.5:
                ra, rb = "W", "L"
                print(f"{a.name} 头游获胜！")
            else:
                ra, rb = "L", "W"
                print(f"{b.name} 头游获胜！")
        else:
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  [{ra}]")

        winner = a if ra == "W" else b
        loser = b if ra == "W" else a
        quarter_results.append(winner)
        quarter_losers.append(loser)

    # ── 1/4 决赛 (8→4) ──
    qf_matches = [
        (quarter_results[0], quarter_results[1], "QF1"),
        (quarter_results[2], quarter_results[3], "QF2"),
        (quarter_results[4], quarter_results[5], "QF3"),
        (quarter_results[6], quarter_results[7], "QF4"),
    ]

    print(f"\n  ── 1/4 决赛 ──")
    semi_results = []
    qf_losers = []
    qf_match_log = []

    for idx, (a, b, label) in enumerate(qf_matches):
        a.reset_stats()
        b.reset_stats()
        ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)
        qf_match_log.append((a, b, ra, rb, la, lb, "1/4", idx + 1))

        if ra == "D":
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  平局！加赛...", end=" ")
            extra_roll = rng.random()
            if extra_roll > 0.5:
                ra, rb = "W", "L"
                print(f"{a.name} 头游获胜！")
            else:
                ra, rb = "L", "W"
                print(f"{b.name} 头游获胜！")
        else:
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  [{ra}]")

        winner = a if ra == "W" else b
        loser = b if ra == "W" else a
        semi_results.append(winner)
        qf_losers.append(loser)

    # ── 半决赛 (4→2) ──
    sf_matches = [
        (semi_results[0], semi_results[1], "SF1"),
        (semi_results[2], semi_results[3], "SF2"),
    ]

    print(f"\n  ── 半决赛 ──")
    finalists = []
    sf_losers = []
    sf_match_log = []

    for idx, (a, b, label) in enumerate(sf_matches):
        a.reset_stats()
        b.reset_stats()
        ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)
        sf_match_log.append((a, b, ra, rb, la, lb, "半决赛", idx + 1))

        if ra == "D":
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  平局！加赛...", end=" ")
            extra_roll = rng.random()
            if extra_roll > 0.5:
                ra, rb = "W", "L"
                print(f"{a.name} 头游获胜！")
            else:
                ra, rb = "L", "W"
                print(f"{b.name} 头游获胜！")
        else:
            print(f"    {label}: {a.display():20s} vs {b.display():20s}  "
                  f"{la}-{lb}  [{ra}]")

        winner = a if ra == "W" else b
        loser = b if ra == "W" else a
        finalists.append(winner)
        sf_losers.append(loser)

    # ── 决赛 ──
    print(f"\n  ── 决赛 ──")
    a, b = finalists[0], finalists[1]
    a.reset_stats()
    b.reset_stats()
    ra, rb, la, lb, net_a, net_b, cum_a, cum_b = play_match(a, b, time_limit, rng)

    if ra == "D":
        print(f"    决赛: {a.display():20s} vs {b.display():20s}  "
              f"{la}-{lb}  平局！加赛...", end=" ")
        extra_roll = rng.random()
        if extra_roll > 0.5:
            ra, rb = "W", "L"
            champion, runner_up = a, b
            print(f"{a.name} 头游获胜！")
        else:
            ra, rb = "L", "W"
            champion, runner_up = b, a
            print(f"{b.name} 头游获胜！")
    else:
        print(f"    决赛: {a.display():20s} vs {b.display():20s}  "
              f"{la}-{lb}  [{ra}]")
        champion = a if ra == "W" else b
        runner_up = b if ra == "W" else a

    final_match_log = [(a, b, ra, rb, la, lb, "决赛", 1)]

    # ── 季军赛 ──
    print(f"\n  ── 季军争夺战 ──")
    a3, b3 = sf_losers[0], sf_losers[1]
    a3.reset_stats()
    b3.reset_stats()
    ra3, rb3, la3, lb3, _, _, _, _ = play_match(a3, b3, time_limit, rng)

    third_match_log = []
    if ra3 == "D":
        print(f"    季军赛: {a3.display():20s} vs {b3.display():20s}  "
              f"{la3}-{lb3}  平局！加赛...", end=" ")
        extra_roll = rng.random()
        if extra_roll > 0.5:
            third, fourth = a3, b3
            print(f"{a3.name} 头游获胜！")
        else:
            third, fourth = b3, a3
            print(f"{b3.name} 头游获胜！")
    else:
        print(f"    季军赛: {a3.display():20s} vs {b3.display():20s}  "
              f"{la3}-{lb3}  [{ra3}]")
        third = a3 if ra3 == "W" else b3
        fourth = b3 if ra3 == "W" else a3
    third_match_log.append((a3, b3, ra3, rb3, la3, lb3, "季军赛", 1))

    # 排名: 1,2,3,4 + QF败者 + 1/8败者 (按各自阶段积分排)
    qf_losers_sorted = sorted(qf_losers, key=lambda t: t.field_score, reverse=True)
    ro16_losers_sorted = sorted(quarter_losers, key=lambda t: t.field_score, reverse=True)

    final_ranking = [champion, runner_up, third, fourth] + qf_losers_sorted + ro16_losers_sorted

    # 保存全部比赛日志和最终结果
    all_elim_matches = r16_match_log + qf_match_log + sf_match_log + final_match_log + third_match_log
    _write_elim_match_log(all_elim_matches, "taotaisai_matches.csv")

    write_teams_csv(final_ranking, "taotaisai_results.csv", extra_cols=[
        ("名次", lambda t: str(final_ranking.index(t) + 1)),
    ])
    print(f"\n  淘汰赛结果已保存: {OUTPUT_DIR}/taotaisai_results.csv")

    return final_ranking


def _write_bracket_csv(bracket: list, filepath: str):
    """淘汰赛对阵表→CSV"""
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["对阵标签", "队伍A", "队员A1", "队员A2", "俱乐部A",
                         "队伍B", "队员B1", "队员B2", "俱乐部B", "同俱乐部"])
        for a, b, label in bracket:
            same = "是" if (a.club and b.club and a.club == b.club) else ""
            writer.writerow([label,
                a.name, a.player1, a.player2, a.club,
                b.name, b.player1, b.player2, b.club, same])


def _write_elim_match_log(matches: list, filepath: str):
    """淘汰赛全部比赛→CSV"""
    ensure_output_dir()
    full_path = os.path.join(OUTPUT_DIR, filepath)
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["阶段", "序号", "队伍A", "队伍B", "结果A", "级数A", "结果B", "级数B",
                         "俱乐部A", "俱乐部B"])
        for a, b, ra, rb, la, lb, stage, seq in matches:
            writer.writerow([stage, seq, a.name, b.name, ra, la, rb, lb, a.club, b.club])


# ═══════════════════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════════════════

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="掼蛋锦标赛完整仿真系统",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
赛程：海选赛(瑞士移位制) → 小组赛(单循环) → 淘汰赛(16强单败)

中间文件输出到 output/ 目录，包括：
  haixuansai_round1.csv ~ haixuansai_round4.csv   各轮积分
  haixuansai_pairings_round1.csv ~ ...             各轮对阵表
  xiaozusai_groups.csv / xiaozusai_top16.csv      小组赛
  taotaisai_bracket.csv / taotaisai_results.csv   淘汰赛

示例:
  python simulate_guandan.py                        # 默认完整仿真
  python simulate_guandan.py -i my_teams.csv        # 指定输入
  python simulate_guandan.py -o my_output           # 指定输出目录
  python simulate_guandan.py --swiss-rounds 3       # 海选赛 3 轮
        """
    )
    parser.add_argument("-i", "--input", default="../docs/attendance.csv",
                        help="输入队伍名单 CSV (默认: ../docs/attendance.csv)")
    parser.add_argument("-o", "--output-dir", default="../output",
                        help="中间文件输出目录 (默认: ../output/)")
    parser.add_argument("--swiss-rounds", type=int, default=4,
                        help="海选赛轮次 (默认: 4)")
    parser.add_argument("--swiss-seed", type=int, default=42,
                        help="海选赛随机种子 (默认: 42)")
    parser.add_argument("--group-seed", type=int, default=7,
                        help="小组赛随机种子 (默认: 7)")
    parser.add_argument("--elim-seed", type=int, default=13,
                        help="淘汰赛随机种子 (默认: 13)")
    parser.add_argument("--top-n", type=int, default=32,
                        help="海选赛晋级人数 (默认: 32)")
    parser.add_argument("--num-groups", type=int, default=8,
                        help="小组赛分组数 (默认: 8)")
    parser.add_argument("--group-size", type=int, default=4,
                        help="每组队伍数 (默认: 4)")
    parser.add_argument("--swiss-time", type=int, default=70,
                        help="海选赛每局限时(分钟) (默认: 70)")
    parser.add_argument("--group-time", type=int, default=70,
                        help="小组赛每局限时(分钟) (默认: 70)")
    parser.add_argument("--elim-time", type=int, default=120,
                        help="淘汰赛每局限时(分钟) (默认: 120)")
    args = parser.parse_args()

    # 设置输出目录
    global OUTPUT_DIR
    OUTPUT_DIR = args.output_dir
    ensure_output_dir()

    print("掼蛋锦标赛仿真系统")
    print("=" * 70)
    print(f"加载报名数据: {args.input}")

    teams = load_teams(args.input)
    print(f"共加载 {len(teams)} 支队伍\n")

    # 显示所有队伍
    for tid in sorted(teams.keys()):
        t = teams[tid]
        club_str = f" [{t.club}]" if t.club else ""
        print(f"  {tid:2d}. {t.display():28s}  {t.gender1}/{t.gender2}{club_str}")

    # ── 阶段一：海选赛 ──
    top_teams = run_haixuansai(
        teams,
        num_rounds=args.swiss_rounds,
        time_limit=args.swiss_time,
        seed=args.swiss_seed,
        top_n=args.top_n,
    )

    # ── 阶段二：小组赛 ──
    top16 = run_xiaozusai(
        teams,
        top_teams,
        num_groups=args.num_groups,
        group_size=args.group_size,
        time_limit=args.group_time,
        seed=args.group_seed,
    )

    # ── 阶段三：淘汰赛 ──
    final_ranking = run_taotaisai(
        teams,
        top16,
        time_limit=args.elim_time,
        seed=args.elim_seed,
    )

    # ── 最终结果 ──
    champion = final_ranking[0]
    runner_up = final_ranking[1]
    third = final_ranking[2]

    print(f"\n{'='*70}")
    print(f"{'='*70}")
    print(f"                        最 终 排 名")
    print(f"{'='*70}")
    print(f"{'='*70}")

    medals = ["🏆", "🥈", "🥉"]
    for i, t in enumerate(final_ranking[:8]):
        medal = medals[i] if i < 3 else f"  "
        club = f"  [{t.club}]" if t.club else ""
        print(f"  {medal} 第 {i+1} 名: {t.display():28s}{club}")

    print(f"\n{'─'*70}")
    print(f"  冠军: {champion.name}")
    print(f"  队员: {champion.player1} ({champion.gender1}) / {champion.player2} ({champion.gender2})")
    if champion.club:
        print(f"  俱乐部: {champion.club}")

    print(f"\n  亚军: {runner_up.name}")
    print(f"  队员: {runner_up.player1} ({runner_up.gender1}) / {runner_up.player2} ({runner_up.gender2})")
    if runner_up.club:
        print(f"  俱乐部: {runner_up.club}")

    print(f"\n  季军: {third.name}")
    print(f"  队员: {third.player1} ({third.gender1}) / {third.player2} ({third.gender2})")
    if third.club:
        print(f"  俱乐部: {third.club}")

    print(f"\n  ── 前 8 强 ──")
    for i, t in enumerate(final_ranking[3:8]):
        club = f"  [{t.club}]" if t.club else ""
        print(f"  第 {i+4} 名: {t.display():28s}{club}")

    print(f"\n{'='*70}")
    print(f"  仿真完成！中间文件保存于: {OUTPUT_DIR}/")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
