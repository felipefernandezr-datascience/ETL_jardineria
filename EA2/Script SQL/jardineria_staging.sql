DROP DATABASE IF EXISTS jardineria_staging;
CREATE DATABASE jardineria_staging;
USE jardineria_staging;


-- 1. Tabla de Categorías
CREATE TABLE Stg_Categoria (
    ID_categoria INT PRIMARY KEY,
    Desc_Categoria VARCHAR(50) NOT NULL
);

-- 2. Tabla de Productos
CREATE TABLE Stg_Producto (
    ID_producto INT PRIMARY KEY,
    nombre VARCHAR(70) NOT NULL,
    ID_categoria INT NOT NULL,
    precio_venta NUMERIC(15,2) NOT NULL,
    FOREIGN KEY (ID_categoria) REFERENCES Stg_Categoria(ID_categoria)
);

-- 3. Tabla de Tiempo
CREATE TABLE Stg_Tiempo (
    ID_tiempo INT PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL
);

-- 4. Tabla Ventas
CREATE TABLE Stg_Ventas (
    ID_venta INT IDENTITY(1,1) PRIMARY KEY,
    ID_producto INT NOT NULL,
    ID_tiempo INT NOT NULL,
    cantidad INT NOT NULL,
    FOREIGN KEY (ID_producto) REFERENCES Stg_Producto(ID_producto),
    FOREIGN KEY (ID_tiempo) REFERENCES Stg_Tiempo(ID_tiempo)
);



-- PROCESO DE CARGA
-- Categorías
INSERT INTO Stg_Categoria (ID_categoria, Desc_Categoria)
SELECT Id_Categoria, Desc_Categoria
FROM jardineria.dbo.Categoria_producto;

-- Productos
INSERT INTO Stg_Producto (ID_producto, nombre, ID_categoria, precio_venta)
SELECT p.ID_producto, p.nombre, p.Categoria, p.precio_venta
FROM jardineria.dbo.producto p;

-- Tiempo
INSERT INTO Stg_Tiempo (ID_tiempo, fecha, anio)
SELECT 
    ROW_NUMBER() OVER (ORDER BY fecha_pedido),
    fecha_pedido,
    YEAR(fecha_pedido)
FROM (SELECT DISTINCT fecha_pedido FROM jardineria.dbo.pedido) t;

-- Ventas
INSERT INTO Stg_Ventas (ID_producto, ID_tiempo, cantidad)
SELECT 
    dp.ID_producto,
    t.ID_tiempo,
    dp.cantidad
FROM jardineria.dbo.detalle_pedido dp
JOIN jardineria.dbo.pedido p 
    ON dp.ID_pedido = p.ID_pedido
JOIN Stg_Tiempo t 
    ON p.fecha_pedido = t.fecha;


-- Consultas de Análisis en la BD Staging

-- Producto más vendido (por cantidad):
SELECT TOP 1 p.nombre, SUM(v.cantidad) AS total_vendido
FROM Stg_Ventas v
JOIN Stg_Producto p ON v.ID_producto = p.ID_producto
GROUP BY p.nombre
ORDER BY total_vendido DESC;

-- Categoría con más productos:
SELECT TOP 1 c.Desc_Categoria, COUNT(p.ID_producto) AS total_productos
FROM Stg_Producto p
JOIN Stg_Categoria c ON p.ID_categoria = c.ID_categoria
GROUP BY c.Desc_Categoria
ORDER BY total_productos DESC;

-- Año con más ventas:
SELECT TOP 1 t.anio, SUM(v.cantidad) AS total_vendido
FROM Stg_Ventas v
JOIN Stg_Tiempo t ON v.ID_tiempo = t.ID_tiempo
GROUP BY t.anio
ORDER BY total_vendido DESC;