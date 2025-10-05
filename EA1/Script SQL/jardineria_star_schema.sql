USE jardineria_star_schema;

CREATE TABLE FactVentas (
    ID_fact_venta INT IDENTITY(1,1) PRIMARY KEY,   -- Clave surrogate
    
    -- Claves foráneas a dimensiones
    ID_producto INT NOT NULL,      -- FK a DimProducto
    ID_cliente INT NOT NULL,       -- FK a DimCliente
    ID_tiempo INT NOT NULL,        -- FK a DimTiempo
    ID_empleado INT NULL,          -- FK a DimEmpleado (opcional)
    ID_categoria INT NOT NULL,     -- FK a DimCategoria (para análisis agregado)
    
    -- Métricas
    cantidad INT NOT NULL,                         -- Cantidad vendida
    precio_unidad NUMERIC(15,2) NOT NULL,          -- Precio por unidad
    total_venta AS (cantidad * precio_unidad) PERSISTED,  -- Total calculado
     
    -- Relaciones (se agregan después con ALTER TABLE)
    -- FOREIGN KEY (ID_producto) REFERENCES DimProducto(ID_producto),
    -- FOREIGN KEY (ID_cliente) REFERENCES DimCliente(ID_cliente),
    -- FOREIGN KEY (ID_tiempo) REFERENCES DimTiempo(ID_tiempo),
    -- FOREIGN KEY (ID_empleado) REFERENCES DimEmpleado(ID_empleado),
    -- FOREIGN KEY (ID_categoria) REFERENCES DimCategoria(ID_categoria)
);

CREATE TABLE DimProducto (
    ID_producto INT PRIMARY KEY,
    CodigoProducto VARCHAR(15),
    nombre VARCHAR(70),
    proveedor VARCHAR(50),
    dimensiones VARCHAR(25),
    precio_venta NUMERIC(15,2),
    precio_proveedor NUMERIC(15,2),
    ID_categoria INT
);

CREATE TABLE DimCategoria (
    ID_categoria INT PRIMARY KEY,
    Desc_Categoria VARCHAR(50),
    descripcion_texto TEXT,
    imagen VARCHAR(256)
);

CREATE TABLE DimCliente (
    ID_cliente INT PRIMARY KEY,
    nombre_cliente VARCHAR(50),
    nombre_contacto VARCHAR(30),
    apellido_contacto VARCHAR(30),
    telefono VARCHAR(15),
    fax VARCHAR(15),
    ciudad VARCHAR(50),
    region VARCHAR(50),
    pais VARCHAR(50),
    codigo_postal VARCHAR(10),
    limite_credito NUMERIC(15,2)
);

CREATE TABLE DimTiempo (
    ID_tiempo INT PRIMARY KEY,
    fecha DATE,
    dia INT,
    mes INT,
    trimestre INT,
    año INT
);

CREATE TABLE DimEmpleado (
    ID_empleado INT PRIMARY KEY,
    nombre VARCHAR(50),
    apellido1 VARCHAR(50),
    apellido2 VARCHAR(50),
    email VARCHAR(100),
    puesto VARCHAR(50),
    ID_oficina INT
);

ALTER TABLE FactVentas
ADD CONSTRAINT FK_FactVentas_Producto
FOREIGN KEY (ID_producto) REFERENCES DimProducto(ID_producto);

ALTER TABLE FactVentas
ADD CONSTRAINT FK_FactVentas_Cliente
FOREIGN KEY (ID_cliente) REFERENCES DimCliente(ID_cliente);

ALTER TABLE FactVentas
ADD CONSTRAINT FK_FactVentas_Tiempo
FOREIGN KEY (ID_tiempo) REFERENCES DimTiempo(ID_tiempo);

ALTER TABLE FactVentas
ADD CONSTRAINT FK_FactVentas_Categoria
FOREIGN KEY (ID_categoria) REFERENCES DimCategoria(ID_categoria);

ALTER TABLE FactVentas
ADD CONSTRAINT FK_FactVentas_Empleado
FOREIGN KEY (ID_empleado) REFERENCES DimEmpleado(ID_empleado);


-- PROCESO DE CARGA
-- DimCategoria
INSERT INTO jardineria_star_schema.dbo.DimCategoria (ID_categoria, Desc_Categoria, descripcion_texto, imagen)
SELECT 
    Id_Categoria,
    Desc_Categoria,
    descripcion_texto,
    imagen
FROM jardineria.dbo.Categoria_producto;


-- DimProducto
INSERT INTO jardineria_star_schema.dbo.DimProducto (ID_producto, CodigoProducto, nombre, proveedor, dimensiones, precio_venta, precio_proveedor, ID_categoria)
SELECT 
    p.ID_producto,
    p.CodigoProducto,
    p.nombre,
    p.proveedor,
    p.dimensiones,
    p.precio_venta,
    p.precio_proveedor,
    p.Categoria
FROM jardineria.dbo.producto p;


-- DimCliente
INSERT INTO jardineria_star_schema.dbo.DimCliente (ID_cliente, nombre_cliente, nombre_contacto, apellido_contacto, telefono, fax, ciudad, region, pais, codigo_postal, limite_credito)
SELECT 
    c.ID_cliente,
    c.nombre_cliente,
    c.nombre_contacto,
    c.apellido_contacto,
    c.telefono,
    c.fax,
    c.ciudad,
    c.region,
    c.pais,
    c.codigo_postal,
    c.limite_credito
FROM jardineria.dbo.cliente c;


-- DimEmpleado
INSERT INTO jardineria_star_schema.dbo.DimEmpleado (ID_empleado, nombre, apellido1, apellido2, email, puesto, ID_oficina)
SELECT 
    e.ID_empleado,
    e.nombre,
    e.apellido1,
    e.apellido2,
    e.email,
    e.puesto,
    e.ID_oficina
FROM jardineria.dbo.empleado e;


-- DimTiempo
INSERT INTO jardineria_star_schema.dbo.DimTiempo (ID_tiempo, fecha, dia, mes, trimestre, año)
SELECT 
    ROW_NUMBER() OVER (ORDER BY fecha_pedido) AS ID_tiempo,
    fecha_pedido AS fecha,
    DAY(fecha_pedido) AS dia,
    MONTH(fecha_pedido) AS mes,
    DATEPART(QUARTER, fecha_pedido) AS trimestre,
    YEAR(fecha_pedido) AS año
FROM (
    SELECT DISTINCT fecha_pedido
    FROM jardineria.dbo.pedido
) t;


-- FactVentas
INSERT INTO jardineria_star_schema.dbo.FactVentas (ID_producto, ID_cliente, ID_tiempo, ID_empleado, ID_categoria, cantidad, precio_unidad)
SELECT 
    dp.ID_producto,
    p.ID_cliente,
    t.ID_tiempo,
    c.ID_empleado_rep_ventas,  -- empleado asociado al cliente
    pr.Categoria,
    dp.cantidad,
    dp.precio_unidad
FROM jardineria.dbo.detalle_pedido dp
JOIN jardineria.dbo.pedido p 
    ON dp.ID_pedido = p.ID_pedido
JOIN jardineria_star_schema.dbo.DimTiempo t
    ON p.fecha_pedido = t.fecha
JOIN jardineria.dbo.producto pr 
    ON dp.ID_producto = pr.ID_producto
JOIN jardineria.dbo.cliente c 
    ON p.ID_cliente = c.ID_cliente;