CREATE OR REPLACE TABLE
 `proyecto2-478014.analisis_mortalidad_pm25.analisis_mortalidad_pm25_resultado` AS

WITH agregados AS (
  SELECT
    categoriapm25,
    SUM(N_MUERTES) AS muertes,
    SUM(NACIDOS_VIVOS) AS nacidos
  FROM
    `proyecto2-478014.analisis_mortalidad_pm25.HechosMortalidad`
  GROUP BY
    categoriapm25
),

-- Aseguramos que existan las 3 categorías
categorias AS (
  SELECT 'Alta' AS cat UNION ALL
  SELECT 'Media' UNION ALL
  SELECT 'Baja'
),

tabla AS (
  SELECT
    cat AS categoria,
    IFNULL(a.muertes, 0) AS muertes,
    IFNULL(a.nacidos, 0) AS nacidos
  FROM categorias c
  LEFT JOIN agregados a
  ON c.cat = a.categoriapm25
),

totales AS (
  SELECT
    SUM(muertes) AS total_muertes,
    SUM(nacidos) AS total_nacidos
  FROM tabla
),

chi2_calc AS (
  SELECT
    SUM( (t.muertes - (t.nacidos * tot.total_muertes / tot.total_nacidos)) *
         (t.muertes - (t.nacidos * tot.total_muertes / tot.total_nacidos)) /
         NULLIF((t.nacidos * tot.total_muertes / tot.total_nacidos), 0)
       ) AS chi2
  FROM tabla t, totales tot
),

medidas AS (

  SELECT
    -- Datos por categoría
    tA.muertes AS muertes_alta,
    tA.nacidos AS nacidos_alta,
    tB.muertes AS muertes_baja,
    tB.nacidos AS nacidos_baja
  FROM tabla tA
  JOIN tabla tB
    ON tA.categoria = 'Alta'
   AND tB.categoria = 'Baja'
),

final_calc AS (
  SELECT
    0.05 AS Suma_de_alpha,

    chi.chi2 AS Suma_de_Estadistico,

    EXP(-0.5 * chi.chi2) AS p_value,

    -- OR = oddsAlta / oddsBaja
    SAFE_DIVIDE(
      SAFE_DIVIDE(m.muertes_alta, NULLIF(m.nacidos_alta - m.muertes_alta, 0)),
      SAFE_DIVIDE(m.muertes_baja, NULLIF(m.nacidos_baja - m.muertes_baja, 0))
    ) AS Odds_ratio,

    -- Risk ratio
    SAFE_DIVIDE(
      SAFE_DIVIDE(m.muertes_alta, NULLIF(m.nacidos_alta, 0)),
      SAFE_DIVIDE(m.muertes_baja, NULLIF(m.nacidos_baja, 0))
    ) AS Risk_ratio

  FROM chi2_calc chi
  CROSS JOIN medidas m
),

interpretacion AS (
  SELECT
    *,
    CASE WHEN p_value < Suma_de_alpha THEN 'Rechaza H0' ELSE 'No rechaza H0' END AS decision,
    CASE WHEN p_value < Suma_de_alpha THEN 'Hay asociación significativa'
         ELSE 'No hay asociación significativa' END AS interpretacion,
    CASE WHEN p_value < Suma_de_alpha THEN 'Sí' ELSE 'No' END AS Significancia,
    'Chi-cuadrado' AS Tipo_de_prueba,
    p_value AS p_value_asociacion
  FROM final_calc
)

SELECT
  Suma_de_alpha,
  decision,
  Suma_de_Estadistico,
  interpretacion,
  p_value,
  Tipo_de_prueba,
  Odds_ratio,
  p_value_asociacion,
  Risk_ratio,
  Significancia
FROM interpretacion;

