DROP DATABASE IF EXISTS jardineria_data_mart;
GO

CREATE DATABASE jardineria_data_mart;
GO

USE jardineria_data_mart;
GO



-- 1. DIMENSIONES

-- Dimensión Categoría
CREATE TABLE Dim_Categoria (
    Id_Categoria INT PRIMARY KEY,
    Desc_Categoria VARCHAR(50)
);

-- Dimensión Producto
CREATE TABLE Dim_Producto (
    Id_Producto INT PRIMARY KEY,
    Nombre VARCHAR(70),
    Id_Categoria INT NOT NULL,
    Precio_Venta NUMERIC(15,2),
    Descripcion VARCHAR(MAX),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (Id_Categoria)
        REFERENCES Dim_Categoria(Id_Categoria)
);

-- Dimensión Tiempo
CREATE TABLE Dim_Tiempo (
    Id_Tiempo INT PRIMARY KEY,
    Fecha DATE NOT NULL,
    Anio INT NOT NULL,
    Mes INT NOT NULL,
    Trimestre INT NOT NULL
);


-- 2. TABLA DE HECHOS
CREATE TABLE Fact_Ventas (
    Id_Venta INT IDENTITY(1,1) PRIMARY KEY,
    Id_Producto INT NOT NULL,
    Id_Tiempo INT NOT NULL,
    Cantidad INT NOT NULL,
    Total NUMERIC(15,2) NOT NULL,
    CONSTRAINT FK_FactVentas_Producto FOREIGN KEY (Id_Producto) REFERENCES Dim_Producto(Id_Producto),
    CONSTRAINT FK_FactVentas_Tiempo FOREIGN KEY (Id_Tiempo) REFERENCES Dim_Tiempo(Id_Tiempo)
);



-- Cargar los Datos desde jardineria_staging.limpio

-- Cargar Categorías
INSERT INTO Dim_Categoria (Id_Categoria, Desc_Categoria)
SELECT Id_Categoria, Desc_Categoria
FROM jardineria_staging.limpio.Categoria;

-- Cargar Productos
INSERT INTO Dim_Producto (Id_Producto, Nombre, Id_Categoria, Precio_Venta, Descripcion)
SELECT p.ID_producto, p.nombre, p.Categoria, p.precio_venta, p.descripcion
FROM jardineria_staging.limpio.Producto p
JOIN jardineria_staging.limpio.Categoria c ON p.Categoria = c.Id_Categoria;

-- Cargar Tiempo
INSERT INTO Dim_Tiempo (Id_Tiempo, Fecha, Anio, Mes, Trimestre)
SELECT ID_tiempo, fecha, anio, mes, trimestre
FROM jardineria_staging.limpio.Tiempo;

-- Cargar Hechos de Ventas
INSERT INTO Fact_Ventas (Id_Producto, Id_Tiempo, Cantidad, Total)
SELECT dp.ID_producto,
       t.ID_tiempo,
       dp.cantidad,
       dp.cantidad * dp.precio_unidad AS total
FROM jardineria_staging.limpio.DetallePedido dp
JOIN jardineria_staging.limpio.Pedido p ON dp.ID_pedido = p.ID_pedido
JOIN jardineria_staging.limpio.Tiempo t ON p.fecha_pedido = t.fecha;



-- Consultas de Negocio en el Data Mart

-- Producto más vendido
SELECT TOP 1 pr.Nombre, SUM(fv.Cantidad) AS Total_Vendido
FROM Fact_Ventas fv
JOIN Dim_Producto pr ON fv.Id_Producto = pr.Id_Producto
GROUP BY pr.Nombre
ORDER BY Total_Vendido DESC;


-- Categoría con más productos
SELECT TOP 1 c.Desc_Categoria, COUNT(p.Id_Producto) AS Cantidad_Productos
FROM Dim_Producto p
JOIN Dim_Categoria c ON p.Id_Categoria = c.Id_Categoria
GROUP BY c.Desc_Categoria
ORDER BY Cantidad_Productos DESC;


-- Año con más ventas
SELECT TOP 1 t.Anio, SUM(fv.Total) AS Ventas_Totales
FROM Fact_Ventas fv
JOIN Dim_Tiempo t ON fv.Id_Tiempo = t.Id_Tiempo
GROUP BY t.Anio
ORDER BY Ventas_Totales DESC;
