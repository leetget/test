CREATE TABLE public.publication(
    id SMALLSERIAL PRIMARY KEY ,
    pub_date TIMESTAMP,
    like_cnt INTEGER
);

-- page: https://vk.com/durov

-- Время суток публикации
with cte as(
    select *,
    CASE
        WHEN EXTRACT(HOUR from pub_date) BETWEEN 4 and 11 THEN 'Утро'
        WHEN EXTRACT(HOUR from pub_date) BETWEEN 12 and 17 THEN 'День'
        WHEN EXTRACT(HOUR from pub_date) BETWEEN 18 and 23 THEN 'Вечер'
        ELSE 'Ночь' end as day_time
    -- 11 публикаций вечером, 4 днем, 3 утром
    from public.publication
)
select distinct day_time,
       avg(like_cnt) OVER (PARTITION BY day_time ) as total
from cte
order by total desc; -- в среднем, больше всего лайков собрали дневные посты, но там и выборка почти в 3 раза меньше
-- разброс между максимумом и минимумом = 67065 лайков
/*
День,100972.5
Вечер,80643.181818181818
Утро,33907.666666666667
*/
-- День недели публикации
select sum(like_cnt),extract(isodow from pub_date) as week_num from public.publication
-- День недели, считая с понедельника (1) до воскресенья (7)
-- (https://postgrespro.ru/docs/postgresql/current/functions-datetime)
GROUP BY week_num
order by 1 desc;
-- Больше всего лайков было во вторник, меньше всего в воскресенье
-- разброс между максимумом и минимумом = 432358 лайков

-- Промежуток между публикациями
with cte as (
    select *,
    --LAG(like_cnt) OVER(ORDER BY pub_date),
    ROUND(extract(epoch from (pub_date - LAG(pub_date) OVER(ORDER BY pub_date))) / 3600,2) as hours_between
    --количество секунд с начала отсчёта Unix-времени(перевел в часы)
    from public.publication
)
SELECT
    CASE
        when hours_between is NULL then 'Первый пост'
        when hours_between < 1 THEN 'Менее часа'
        WHEN hours_between < 12 THEN '1-12 часов'
        WHEN hours_between < 24 THEN 'Менее одного дня'
        WHEN hours_between < 72 THEN 'Менее трех суток'
        WHEN hours_between < 168 THEN 'Менее недели'
        ELSE 'Больше недели' end as time_interval,
        COUNT(1) as pub_count,
        avg(like_cnt) as like_avg
from cte
group by
    CASE
        when hours_between is NULL then 'Первый пост'
        when hours_between < 1 THEN 'Менее часа'
        WHEN hours_between < 12 THEN '1-12 часов'
        WHEN hours_between < 24 THEN 'Менее одного дня'
        WHEN hours_between < 72 THEN 'Менее трех суток'
        WHEN hours_between < 168 THEN 'Менее недели'
        ELSE 'Больше недели' END order by like_avg desc;
-- Больше всего лайков было с промежутком постов менее недели(146108), меньшее всего с промежутком менее часа(35549)
-- Разница между максимумом и минимумом = 110559 лайков
/*
Менее недели,3,146108.666666666667
Первый пост,1,107056
Менее трех суток,5,80321.8
1-12 часов,5,55497
Менее одного дня,2,48556.5
Менее часа,2,35549.5
 */

-- Исходя из этого, больше всего на количество лайков влияют дни недели публикации
-- так как там самый высокий разброс значений между показателями минимума и максимума
