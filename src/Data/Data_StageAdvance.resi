/**
  多阶段赛事晋级逻辑。
  参照南山杯 Aotearoa 掼蛋大赛指南（2026）。

  流程：
  - 海选赛（Swiss）结束后，取积分榜前 N 名晋级小组赛
  - 小组赛（GroupStage）结束后，每组前 M 名晋级淘汰赛
  - 淘汰赛（Knockout）结束后，冠军产生
*/

/** 从海选赛积分数据中获取前N名队伍ID，按排名降序排列 */
let getSwissAdvancingTeams: (Data_Id.Map.t<Data_Scoring.t>, int) => array<Data_Id.t>

/** 从小组赛数据中获取每组前perGroup名队伍ID，按交叉对阵顺序排列。
  * 返回的队伍顺序可直接用于淘汰赛种子排位。
  * 例如 8 组每组前 2 名 → 16 队，按 A1, B2, C1, D2, E1, F2, G1, H2, B1, A2, D1, C2, F1, E2, H1, G2 排列 */
let getGroupAdvancingTeams: (
  Data_Rounds.t,
  Data_Id.Map.t<int>,
  int,
  ~perGroup: int,
) => array<Data_Id.t>

/** 下一阶段格式类型标记 */
type nextStageKind = SwissToGroup | GroupToKnockout

/** 计算下一阶段的赛制参数 */
type nextStageParams = {
  kind: nextStageKind,
  name: string,
  /** 晋级队伍数 */
  advanceCount: int,
  /** 默认时间限制（分钟） */
  timeLimitMinutes: int,
  /** 小组赛：分组数。淘汰赛：队伍规模。 */
  stageParam: int,
}

/** 根据当前赛制和队伍数获取下一阶段的参数。
  * 调用方可用 stageParam 构建具体的 Format.t：
  * - SwissToGroup: GroupStage({groupCount: stageParam})
  * - GroupToKnockout: Knockout({teamCount: stageParam}) */
let getNextStageParams: (Data_Tournament.Format.t, int) => option<nextStageParams>

/** 从 GroupStage.generateSchedule 返回的 groups 构建 groupAssignments */
let groupAssignmentsFromGroups: (array<Data_GroupStage.group>, Data_Id.Map.t<Data_Team.t>) => Data_Id.Map.t<int>
