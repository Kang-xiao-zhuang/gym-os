-- 给动作补充「要领」(description) 与「建议训练量」(default_sets/reps/weight)。
-- 在 Supabase 控制台 → SQL Editor 执行。按动作名匹配更新，可自行增改/新增。
--
-- 约定：
--   description 多行 = 每行一个要点，App 会自动渲染成带序号的步骤（不用自己写 1. 2.）。
--   多行用 E'...\n...' 写法。
--   自重动作 default_weight 用 NULL。

update public.exercises set
  description = E'肩胛后收下沉，胸腔上挺\n杠铃下放至乳头连线，大臂约 45°\n脚掌踩实发力，全程绷紧核心\n推起时呼气，避免塌肩',
  default_sets = 4, default_reps = 8, default_weight = 60
where name = '杠铃卧推';

update public.exercises set
  description = E'平躺，双手持哑铃微屈肘\n沿弧线下放至胸部有牵拉感\n用胸大肌收缩带动上举\n顶峰稍作挤压',
  default_sets = 3, default_reps = 12, default_weight = 12
where name = '哑铃飞鸟';

update public.exercises set
  description = E'正握略宽于肩，身体微后仰\n背阔肌发力，肘向下后方拉\n下巴过杠，顶峰挤压背部\n缓慢下放，全程控制',
  default_sets = 4, default_reps = 8, default_weight = null
where name = '引体向上';

update public.exercises set
  description = E'杠铃置于斜方肌上沿，双脚与肩同宽\n屈髋屈膝下蹲，膝盖与脚尖同向\n蹲至大腿与地面平行或更低\n脚跟发力站起，全程挺胸收腹',
  default_sets = 5, default_reps = 5, default_weight = 80
where name = '杠铃深蹲';

update public.exercises set
  description = E'坐姿挺直，哑铃举至耳侧\n垂直上推至手臂接近伸直\n顶端不要完全锁死\n缓慢下放至起始位',
  default_sets = 4, default_reps = 10, default_weight = 15
where name = '坐姿推举';

update public.exercises set
  description = E'俯撑，前臂着地，肘在肩正下方\n头、背、臀、腿成一条直线\n收紧核心与臀部，均匀呼吸\n每组保持 30–60 秒',
  default_sets = 3, default_reps = null, default_weight = null
where name = '平板支撑';

update public.exercises set
  description = E'双手撑于双杠，身体前倾\n屈肘下放至大臂与地面平行\n胸部发力撑起，顶端伸直\n控制节奏，避免耸肩',
  default_sets = 3, default_reps = 10, default_weight = null
where name = '臂力屈伸';

-- 新增动作时仿照上面：where name = '你的动作名'。执行后 App 刷新即可看到。
