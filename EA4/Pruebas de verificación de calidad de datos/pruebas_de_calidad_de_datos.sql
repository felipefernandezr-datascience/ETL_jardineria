USE jardineria_data_mart;

-- 1. Completitud

-- Productos sin categoría
SELECT * 
FROM Dim_Producto
WHERE Id_Categoria IS NULL;

-- Ventas sin referencia de tiempo
SELECT * 
FROM Fact_Ventas
WHERE Id_Tiempo IS NULL;

-- Ventas con cantidad o total nulos
SELECT * 
FROM Fact_Ventas
WHERE Cantidad IS NULL OR Total IS NULL;



-- 2. Validez

-- Cantidad y total deben ser positivos
SELECT * 
FROM Fact_Ventas
WHERE Cantidad <= 0 OR Total <= 0;

-- Fechas válidas (no futuras)
SELECT * 
FROM Dim_Tiempo
WHERE Fecha > GETDATE();


-- 3. Consistencia

-- Productos en hechos que no existen en dimensión
SELECT fv.Id_Producto
FROM Fact_Ventas fv
LEFT JOIN Dim_Producto dp ON fv.Id_Producto = dp.Id_Producto
WHERE dp.Id_Producto IS NULL;

-- Categorías huérfanas
SELECT p.Id_Producto
FROM Dim_Producto p
LEFT JOIN Dim_Categoria c ON p.Id_Categoria = c.Id_Categoria
WHERE c.Id_Categoria IS NULL;


-- 4. Exactitud

-- Comparación entre ventas en limpio y ventas en data mart
USE jardineria_staging;
SELECT SUM(total) AS Total_Limpio FROM limpio.Ventas;

USE jardineria_data_mart;
SELECT SUM(Total) AS Total_DataMart FROM Fact_Ventas;


-- 5. Unicidades

-- IDs duplicados en dimensiones
SELECT Id_Producto, COUNT(*) 
FROM Dim_Producto
GROUP BY Id_Producto
HAVING COUNT(*) > 1;

-- Fechas duplicadas en Dim_Tiempo
SELECT Fecha, COUNT(*)
FROM Dim_Tiempo
GROUP BY Fecha
HAVING COUNT(*) > 1;


-- 6. Conformidad

-- Códigos de producto con caracteres no esperados
SELECT Nombre
FROM Dim_Producto
WHERE Nombre NOT LIKE '[A-Z0-9]%';

-- Descripciones vacías
SELECT *
FROM Dim_Producto
WHERE Descripcion IN ('', NULL);
