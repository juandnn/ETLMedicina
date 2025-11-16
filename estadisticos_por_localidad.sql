CREATE OR REPLACE TABLE
 `proyecto2-478014.analisis_mortalidad_pm25.estadisticos_por_localidad` AS
WITH base AS (
  SELECT
    LOCALIDAD,
    PM25_PROM AS x,
    TASA_POR_1000 AS y
  FROM `proyecto2-478014.analisis_mortalidad_pm25.HechosMortalidad`
  WHERE PM25_PROM IS NOT NULL AND TASA_POR_1000 IS NOT NULL
),

stats AS (
  SELECT
    LOCALIDAD,
    COUNT(*) AS n,
    AVG(x) AS mean_x,
    AVG(y) AS mean_y,
    VARIANCE(x) AS var_x,
    COVAR_SAMP(x, y) AS cov_xy,
    CORR(x, y) AS corr_xy
  FROM base
  GROUP BY LOCALIDAD
),

betas AS (
  SELECT
    LOCALIDAD,
    cov_xy / NULLIF(var_x, 0) AS beta,
    corr_xy * corr_xy AS R2,
    mean_x,
    mean_y
  FROM stats
),

residuos AS (
  SELECT
    b.LOCALIDAD,
    b.x,
    b.y,
    s.beta,
    (y - (s.beta * x + (s.mean_y - s.beta * s.mean_x))) AS residuo
  FROM base b
  JOIN betas s USING (LOCALIDAD)
),

mse AS (
  SELECT
    LOCALIDAD,
    SUM(residuo * residuo) / NULLIF(COUNT(*) - 2, 0) AS mse
  FROM residuos
  GROUP BY LOCALIDAD
),

sum_squares_x AS (
  SELECT
    LOCALIDAD,
    SUM(POWER(x - mean_x, 2)) AS ss_x
  FROM base
  JOIN stats USING (LOCALIDAD)
  GROUP BY LOCALIDAD
),

intervalos AS (
  SELECT
    b.LOCALIDAD,
    b.beta,
    m.mse,
    s.ss_x,
    SQRT(m.mse / NULLIF(s.ss_x, 0)) AS se_beta,
    b.R2
  FROM betas b
  JOIN mse m USING (LOCALIDAD)
  JOIN sum_squares_x s USING (LOCALIDAD)
)

SELECT
  LOCALIDAD,
  -- Reemplazamos NaN y NULL directamente
  IF(IS_NAN(IFNULL(ROUND(beta, 6), 0)), 0, ROUND(beta, 6)) AS Beta_ajustado,
  IF(IS_NAN(IFNULL(ROUND(beta - 1.96 * se_beta, 6), 0)), 0, ROUND(beta - 1.96 * se_beta, 6)) AS IC95_inferior,
  IF(IS_NAN(IFNULL(ROUND(beta + 1.96 * se_beta, 6), 0)), 0, ROUND(beta + 1.96 * se_beta, 6)) AS IC95_superior,
  IF(IS_NAN(IFNULL(ROUND(R2, 6), 0)), 0, ROUND(R2, 6)) AS R2
FROM intervalos
ORDER BY LOCALIDAD;

