DROP DATABASE IF EXISTS jardineria_staging;
GO
CREATE DATABASE jardineria_staging;
GO
USE jardineria_staging;
GO



-- 1. CATEGORÍAS
CREATE TABLE Stg_Categoria (
    Id_Categoria INT PRIMARY KEY,
    Desc_Categoria VARCHAR(50),
    descripcion_texto VARCHAR(MAX),
    descripcion_html VARCHAR(MAX),
    imagen VARCHAR(256)
);
GO


-- 2. PRODUCTOS
CREATE TABLE Stg_Producto (
    ID_producto INT PRIMARY KEY,
    CodigoProducto VARCHAR(15),
    nombre VARCHAR(70),
    Categoria INT NOT NULL,
    dimensiones VARCHAR(25),
    proveedor VARCHAR(50),
    descripcion VARCHAR(MAX),
    cantidad_en_stock SMALLINT,
    precio_venta NUMERIC(15,2),
    precio_proveedor NUMERIC(15,2),
    CONSTRAINT FK_StgProducto_Categoria FOREIGN KEY (Categoria)
        REFERENCES Stg_Categoria (Id_Categoria)
);
GO


-- 3. PEDIDOS
CREATE TABLE Stg_Pedido (
    ID_pedido INT PRIMARY KEY,
    fecha_pedido DATE,
    fecha_esperada DATE,
    fecha_entrega DATE,
    estado VARCHAR(15),
    comentarios VARCHAR(MAX),
    ID_cliente INT
    -- No ponemos FK a cliente porque no lo cargamos en staging
);
GO


-- 4. DETALLE DE PEDIDO
CREATE TABLE Stg_DetallePedido (
    ID_detalle_pedido INT PRIMARY KEY,
    ID_pedido INT NOT NULL,
    ID_producto INT NOT NULL,
    cantidad INT,
    precio_unidad NUMERIC(15,2),
    numero_linea SMALLINT,
    CONSTRAINT FK_StgDetallePedido_Pedido FOREIGN KEY (ID_pedido)
        REFERENCES Stg_Pedido (ID_pedido),
    CONSTRAINT FK_StgDetallePedido_Producto FOREIGN KEY (ID_producto)
        REFERENCES Stg_Producto (ID_producto)
);
GO



-- Carga en crudo desde la BD jardineria

-- Categorías
INSERT INTO Stg_Categoria
SELECT Id_Categoria, Desc_Categoria, descripcion_texto, descripcion_html, imagen
FROM jardineria.dbo.Categoria_producto;
GO

-- Productos
INSERT INTO Stg_Producto
SELECT ID_producto, CodigoProducto, nombre, Categoria, dimensiones, proveedor, descripcion,
       cantidad_en_stock, precio_venta, precio_proveedor
FROM jardineria.dbo.Producto;
GO

-- Pedidos
INSERT INTO Stg_Pedido
SELECT ID_pedido, fecha_pedido, fecha_esperada, fecha_entrega, estado, comentarios, ID_cliente
FROM jardineria.dbo.Pedido;
GO

-- Detalle de pedido
INSERT INTO Stg_DetallePedido
SELECT ID_detalle_pedido, ID_pedido, ID_producto, cantidad, precio_unidad, numero_linea
FROM jardineria.dbo.Detalle_pedido;
GO



-- Consultas de validación por tabla

-- 1. Stg_Categoria

-- a. Categorías sin descripción
SELECT Id_Categoria
FROM Stg_Categoria
WHERE Desc_Categoria IS NULL OR LTRIM(RTRIM(Desc_Categoria)) = '';

-- b. Categorías sin productos asociados
SELECT c.Id_Categoria, c.Desc_Categoria
FROM Stg_Categoria c
LEFT JOIN Stg_Producto p ON c.Id_Categoria = p.Categoria
WHERE p.ID_producto IS NULL;


-- 2. Stg_Producto

-- a. Productos sin categoría válida
SELECT p.ID_producto, p.nombre
FROM Stg_Producto p
LEFT JOIN Stg_Categoria c ON p.Categoria = c.Id_Categoria
WHERE c.Id_Categoria IS NULL;

-- b. Precios inválidos
SELECT ID_producto, nombre, precio_venta, precio_proveedor
FROM Stg_Producto
WHERE precio_venta IS NULL OR precio_venta <= 0
   OR precio_proveedor IS NULL OR precio_proveedor <= 0;

-- c. Productos sin descripción
SELECT ID_producto, nombre
FROM Stg_Producto
WHERE descripcion IS NULL OR descripcion = '';

-- d. Dimensiones mal formateadas
SELECT ID_producto, nombre, dimensiones
FROM Stg_Producto
WHERE dimensiones IS NULL 
   OR dimensiones LIKE '%/%'
   OR dimensiones LIKE '%-%';


-- 3. Stg_Pedido

-- a. Pedidos rechazados o pendientes (no deberían cargarse en ventas)
SELECT ID_pedido, estado
FROM Stg_Pedido
WHERE estado IN ('Pendiente', 'Rechazado');

-- b. Fechas inconsistentes
SELECT ID_pedido, fecha_pedido, fecha_esperada, fecha_entrega
FROM Stg_Pedido
WHERE fecha_esperada < fecha_pedido
   OR (fecha_entrega IS NOT NULL AND fecha_entrega < fecha_pedido);


-- 4. Stg_DetallePedido

-- a. Ventas con cantidades inválidas
SELECT ID_detalle_pedido, ID_pedido, ID_producto, cantidad
FROM Stg_DetallePedido
WHERE cantidad <= 0;

-- b. Ventas con precios inválidos
SELECT ID_detalle_pedido, ID_pedido, ID_producto, precio_unidad
FROM Stg_DetallePedido
WHERE precio_unidad <= 0;

-- c. Detalle sin referencia a pedido
SELECT d.ID_detalle_pedido, d.ID_pedido
FROM Stg_DetallePedido d
LEFT JOIN Stg_Pedido p ON d.ID_pedido = p.ID_pedido
WHERE p.ID_pedido IS NULL;

-- d. Detalle sin referencia a producto
SELECT d.ID_detalle_pedido, d.ID_producto
FROM Stg_DetallePedido d
LEFT JOIN Stg_Producto p ON d.ID_producto = p.ID_producto
WHERE p.ID_producto IS NULL;



-- TRANSFORMACIÓN DE DATOS

-- Crear esquemas si no existen
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'crudo')
    EXEC('CREATE SCHEMA crudo');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'limpio')
    EXEC('CREATE SCHEMA limpio');
GO


-- Mover las tablas originales
ALTER SCHEMA crudo TRANSFER dbo.Stg_Categoria;
ALTER SCHEMA crudo TRANSFER dbo.Stg_Producto;
ALTER SCHEMA crudo TRANSFER dbo.Stg_Pedido;
ALTER SCHEMA crudo TRANSFER dbo.Stg_DetallePedido;


-- Crear tablas transformadas en limpio

-- Categorías limpias
CREATE TABLE limpio.Categoria (
    Id_Categoria INT PRIMARY KEY,
    Desc_Categoria VARCHAR(50)
);


-- Productos limpios
CREATE TABLE limpio.Producto (
    ID_producto INT PRIMARY KEY,
    nombre VARCHAR(70),
    Categoria INT NOT NULL,
    precio_venta NUMERIC(15,2),
    descripcion VARCHAR(MAX),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (Categoria) REFERENCES limpio.Categoria(Id_Categoria)
);


-- Pedidos limpios
CREATE TABLE limpio.Pedido (
    ID_pedido INT PRIMARY KEY,
    fecha_pedido DATE,
    estado VARCHAR(15)
);


-- Detalle de pedidos limpios
CREATE TABLE limpio.DetallePedido (
    ID_detalle_pedido INT PRIMARY KEY,
    ID_pedido INT NOT NULL,
    ID_producto INT NOT NULL,
    cantidad INT,
    precio_unidad NUMERIC(15,2),
    CONSTRAINT FK_DetPedido_Pedido FOREIGN KEY (ID_pedido) REFERENCES limpio.Pedido(ID_pedido),
    CONSTRAINT FK_DetPedido_Producto FOREIGN KEY (ID_producto) REFERENCES limpio.Producto(ID_producto)
);


-- Dimensión tiempo
CREATE TABLE limpio.Tiempo (
    ID_tiempo INT PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    trimestre INT NOT NULL
);


-- Hechos de ventas
CREATE TABLE limpio.Ventas (
    ID_venta INT IDENTITY(1,1) PRIMARY KEY,
    ID_producto INT NOT NULL,
    ID_tiempo INT NOT NULL,
    cantidad INT NOT NULL,
    total NUMERIC(15,2) NOT NULL,
    CONSTRAINT FK_Ventas_Producto FOREIGN KEY (ID_producto) REFERENCES limpio.Producto(ID_producto),
    CONSTRAINT FK_Ventas_Tiempo FOREIGN KEY (ID_tiempo) REFERENCES limpio.Tiempo(ID_tiempo)
);



-- Insertar datos transformados en limpio

-- Categorías limpias (excluyendo huérfanas como Herbaceas)
INSERT INTO limpio.Categoria (Id_Categoria, Desc_Categoria)
SELECT c.Id_Categoria, c.Desc_Categoria
FROM crudo.Stg_Categoria c
WHERE EXISTS (
    SELECT 1 FROM crudo.Stg_Producto p WHERE p.Categoria = c.Id_Categoria
);


-- Productos limpios (solo con precio_venta > 0 y categoría válida)
INSERT INTO limpio.Producto (ID_producto, nombre, Categoria, precio_venta, descripcion)
SELECT p.ID_producto,
       p.nombre,
       p.Categoria,
       p.precio_venta,
       ISNULL(NULLIF(LTRIM(RTRIM(p.descripcion)),''), 'No disponible')S
FROM crudo.Stg_Producto p
WHERE p.precio_venta > 0
  AND EXISTS (SELECT 1 FROM limpio.Categoria c WHERE c.Id_Categoria = p.Categoria);


-- Pedidos limpios (solo entregados y con fecha válida)
INSERT INTO limpio.Pedido (ID_pedido, fecha_pedido, estado)
SELECT p.ID_pedido, p.fecha_pedido, p.estado
FROM crudo.Stg_Pedido p
WHERE p.estado = 'Entregado'
  AND p.fecha_pedido IS NOT NULL;


-- Detalles de pedido limpios
INSERT INTO limpio.DetallePedido (ID_detalle_pedido, ID_pedido, ID_producto, cantidad, precio_unidad)
SELECT dp.ID_detalle_pedido,
       dp.ID_pedido,
       dp.ID_producto,
       dp.cantidad,
       dp.precio_unidad
FROM crudo.Stg_DetallePedido dp
JOIN limpio.Pedido pl ON dp.ID_pedido = pl.ID_pedido
JOIN limpio.Producto pr ON dp.ID_producto = pr.ID_producto
WHERE dp.cantidad > 0 AND dp.precio_unidad > 0;


-- Dimensión tiempo
INSERT INTO limpio.Tiempo (ID_tiempo, fecha, anio, mes, trimestre)
SELECT ROW_NUMBER() OVER (ORDER BY p.fecha_pedido) AS ID_tiempo,
       p.fecha_pedido,
       YEAR(p.fecha_pedido) AS anio,
       MONTH(p.fecha_pedido) AS mes,
       DATEPART(QUARTER, p.fecha_pedido) AS trimestre
FROM (
    SELECT DISTINCT fecha_pedido
    FROM limpio.Pedido
    WHERE fecha_pedido IS NOT NULL
) p;


-- Ventas (hechos)
INSERT INTO limpio.Ventas (ID_producto, ID_tiempo, cantidad, total)
SELECT dp.ID_producto,
       t.ID_tiempo,
       dp.cantidad,
       dp.cantidad * dp.precio_unidad AS total
FROM limpio.DetallePedido dp
JOIN limpio.Pedido p ON dp.ID_pedido = p.ID_pedido
JOIN limpio.Tiempo t ON p.fecha_pedido = t.fecha;
