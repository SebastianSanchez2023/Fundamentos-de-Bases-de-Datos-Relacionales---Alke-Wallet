-- =============================================================================
-- PROYECTO: ALKE WALLET
-- MÓDULO: Fundamentos de Bases de Datos Relacionales
-- RDBMS Objetivo: MySQL 8.0+ / MariaDB / SQLiteOnline (MySQL mode)
-- =============================================================================

-- =============================================================================
-- LECCIÓN 1 & 4: DDL (Data Definition Language) - Creación de Base de Datos y Tablas
-- =============================================================================

-- 1. Creación de la Base de Datos
DROP DATABASE IF EXISTS AlkeWallet;
CREATE DATABASE AlkeWallet CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE AlkeWallet;

-- 2. Tabla: MONEDA (Entidad Fuerte / Catálogo de Divisas)
-- Almacena las divisas soportadas por la billetera digital.
CREATE TABLE moneda (
    currency_id INT AUTO_INCREMENT,
    currency_name VARCHAR(50) NOT NULL,
    currency_symbol VARCHAR(10) NOT NULL,
    CONSTRAINT pk_moneda PRIMARY KEY (currency_id),
    CONSTRAINT uq_moneda_name UNIQUE (currency_name),
    CONSTRAINT uq_moneda_symbol UNIQUE (currency_symbol)
) ENGINE=InnoDB;

-- 3. Tabla: USUARIO (Entidad Principal)
-- Representa a cada cliente del sistema monedero virtual.
-- Se relaciona con 'moneda' mediante currency_id para definir su divisa preferida/predeterminada.
CREATE TABLE usuario (
    user_id INT AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL,
    contrasena VARCHAR(255) NOT NULL,
    saldo DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    currency_id INT NOT NULL,
    CONSTRAINT pk_usuario PRIMARY KEY (user_id),
    CONSTRAINT uq_usuario_correo UNIQUE (correo_electronico),
    CONSTRAINT chk_usuario_saldo CHECK (saldo >= 0.00),
    CONSTRAINT fk_usuario_moneda FOREIGN KEY (currency_id) 
        REFERENCES moneda(currency_id)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 4. Tabla: TRANSACCION (Entidad Transaccional)
-- Registra cada transferencia financiera entre usuarios.
-- sender_user_id: usuario que envía los fondos (emisor)
-- receiver_user_id: usuario que recibe los fondos (receptor)
CREATE TABLE transaccion (
    transaction_id INT AUTO_INCREMENT,
    sender_user_id INT NOT NULL,
    receiver_user_id INT NOT NULL,
    currency_id INT NOT NULL,
    importe DECIMAL(12, 2) NOT NULL,
    transaction_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_transaccion PRIMARY KEY (transaction_id),
    CONSTRAINT chk_transaccion_importe CHECK (importe > 0.00),
    CONSTRAINT chk_distintos_usuarios CHECK (sender_user_id <> receiver_user_id),
    CONSTRAINT fk_transaccion_sender FOREIGN KEY (sender_user_id) 
        REFERENCES usuario(user_id)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT,
    CONSTRAINT fk_transaccion_receiver FOREIGN KEY (receiver_user_id) 
        REFERENCES usuario(user_id)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT,
    CONSTRAINT fk_transaccion_moneda FOREIGN KEY (currency_id) 
        REFERENCES moneda(currency_id)
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Índices compuestos para optimización de búsquedas y reportes de transacciones
CREATE INDEX idx_transaccion_emisor_fecha ON transaccion(sender_user_id, transaction_date);
CREATE INDEX idx_transaccion_receptor_fecha ON transaccion(receiver_user_id, transaction_date);

-- Tarea Plus (Lección 4): Modificar tabla usuario para añadir fecha_creacion con ALTER TABLE
ALTER TABLE usuario 
ADD COLUMN fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Comprobación de metadatos (Exploración inicial de objetos)
SHOW TABLES;
DESCRIBE moneda;
DESCRIBE usuario;
DESCRIBE transaccion;


-- =============================================================================
-- LECCIÓN 3: DML (Data Manipulation Language) - Inserciones y Transaccionalidad ACID
-- =============================================================================

-- 1. Insertar Catálogo de Monedas
INSERT INTO moneda (currency_name, currency_symbol) VALUES
('Dólar Estadounidense', 'USD'),
('Peso Chileno', 'CLP'),
('Euro', 'EUR'),
('Peso Argentino', 'ARS');

-- 2. Insertar Usuarios de Prueba
INSERT INTO usuario (nombre, correo_electronico, contrasena, saldo, currency_id) VALUES
('Carlos Mendoza', 'carlos.mendoza@email.com', '$2y$10$e8wFvQ4A...', 150000.00, 2), -- CLP
('Valentina Silva', 'valentina.silva@email.com', '$2y$10$k1wXzL9B...', 2500.50, 1),   -- USD
('Andrés Morales', 'andres.morales@email.com', '$2y$10$p3mNkO7C...', 320000.00, 2), -- CLP
('Camila Rojas', 'camila.rojas@email.com', '$2y$10$q9xRtY1D...', 850.00, 3),        -- EUR
('Mateo Fernández', 'mateo.fernandez@email.com', '$2y$10$w4yUiE3F...', 95000.00, 4),  -- ARS
('Sofía Castro', 'sofia.castro@email.com', '$2y$10$t6uPqA8G...', 450000.00, 2),     -- CLP
('Lucía Navarro', 'lucia.navarro@email.com', '$2y$10$r5tYhJ2K...', 1200.00, 1);      -- USD

-- 3. Inserción de Transacciones Históricas de Prueba
INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe, transaction_date) VALUES
(1, 3, 2, 25000.00, '2026-03-10 10:15:00'),
(3, 6, 2, 50000.00, '2026-03-11 14:30:22'),
(2, 7, 1, 150.00,   '2026-03-12 09:05:40'),
(6, 1, 2, 12000.00, '2026-03-13 18:45:10'),
(7, 2, 1, 300.00,   '2026-03-14 11:20:00'),
(3, 1, 2, 8500.00,  '2026-03-15 16:10:05');

-- 4. Demostración de Transacción Controlada (ACID: START TRANSACTION, COMMIT)
-- Transferencia de 10,000 CLP de Carlos Mendoza (user_id 1) a Andrés Morales (user_id 3)
START TRANSACTION;

-- Paso A: Descontar saldo al emisor
UPDATE usuario 
SET saldo = saldo - 10000.00 
WHERE user_id = 1 AND saldo >= 10000.00;

-- Paso B: Incrementar saldo al receptor
UPDATE usuario 
SET saldo = saldo + 10000.00 
WHERE user_id = 3;

-- Paso C: Registrar movimiento en el libro mayor de transacciones
INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe, transaction_date)
VALUES (1, 3, 2, 10000.00, NOW());

-- Paso D: Confirmar definitivamente los cambios de forma atómica
COMMIT;


-- 5. Demostración de Transacción con Reversión (ROLLBACK ante simulación de error o fondo insuficiente)
START TRANSACTION;

-- Intento de transferencia con rollback manual
UPDATE usuario 
SET saldo = saldo - 5000.00 
WHERE user_id = 2;

-- Se detecta una inconsistencia en la lógica de negocio y se revierte:
ROLLBACK;


-- 6. Simulación de Error de Integridad Referencial (Violación de Clave Foránea)
-- Intento de registrar una transacción con un usuario emisor inexistente (user_id = 9999).
-- El motor InnoDB rechaza la operación garantizando la integridad de datos:
-- INSERT INTO transaccion (sender_user_id, receiver_user_id, currency_id, importe) 
-- VALUES (9999, 1, 1, 100.00); 
-- [Error Code: 1452. Cannot add or update a child row: a foreign key constraint fails]


-- =============================================================================
-- LECCIÓN 2 & REQUERIMIENTOS: Consultas SQL (DQL) y Modificaciones (DML)
-- =============================================================================

-- [Requerimiento 1]: Consulta para obtener el nombre de la moneda elegida por un usuario específico
-- Ejemplo para el usuario 'Carlos Mendoza' o con user_id = 1
SELECT 
    u.user_id,
    u.nombre AS nombre_usuario,
    u.correo_electronico,
    m.currency_name AS nombre_moneda,
    m.currency_symbol AS simbolo_moneda
FROM usuario u
INNER JOIN moneda m ON u.currency_id = m.currency_id
WHERE u.user_id = 1;

-- [Requerimiento 2]: Consulta para obtener todas las transacciones registradas
-- Muestra el detalle con nombres del emisor, receptor, divisa y fecha
SELECT 
    t.transaction_id,
    u_emisor.nombre AS usuario_emisor,
    u_receptor.nombre AS usuario_receptor,
    t.importe,
    m.currency_symbol AS divisa,
    t.transaction_date AS fecha_transaccion
FROM transaccion t
INNER JOIN usuario u_emisor ON t.sender_user_id = u_emisor.user_id
INNER JOIN usuario u_receptor ON t.receiver_user_id = u_receptor.user_id
INNER JOIN moneda m ON t.currency_id = m.currency_id
ORDER BY t.transaction_date DESC;

-- [Requerimiento 3]: Consulta para obtener todas las transacciones realizadas por un usuario específico
-- Considera tanto transacciones enviadas como recibidas por el usuario 1 ('Carlos Mendoza')
SELECT 
    t.transaction_id,
    CASE 
        WHEN t.sender_user_id = 1 THEN 'Enviada'
        ELSE 'Recibida'
    END AS tipo_movimiento,
    u_emisor.nombre AS emisor,
    u_receptor.nombre AS receptor,
    t.importe,
    m.currency_symbol AS divisa,
    t.transaction_date AS fecha
FROM transaccion t
INNER JOIN usuario u_emisor ON t.sender_user_id = u_emisor.user_id
INNER JOIN usuario u_receptor ON t.receiver_user_id = u_receptor.user_id
INNER JOIN moneda m ON t.currency_id = m.currency_id
WHERE t.sender_user_id = 1 OR t.receiver_user_id = 1
ORDER BY t.transaction_date DESC;

-- [Requerimiento 4]: Sentencia DML para modificar el campo correo electrónico de un usuario específico
UPDATE usuario 
SET correo_electronico = 'carlos.mendoza_updated@alke.cl'
WHERE user_id = 1;

-- Verificación de la modificación
SELECT user_id, nombre, correo_electronico 
FROM usuario 
WHERE user_id = 1;

-- [Requerimiento 5]: Sentencia para eliminar los datos de una transacción (eliminado de la fila completa)
DELETE FROM transaccion 
WHERE transaction_id = 6;

-- Verificación de la eliminación
SELECT * FROM transaccion WHERE transaction_id = 6;


-- =============================================================================
-- CONSULTAS ADICIONALES DE LA LECCIÓN 2 (Agregaciones, Subconsultas y Vista Plus)
-- =============================================================================

-- Subconsulta: Total de transacciones emitidas por cada usuario
SELECT 
    u.user_id,
    u.nombre,
    (SELECT COUNT(*) 
     FROM transaccion t 
     WHERE t.sender_user_id = u.user_id) AS total_transacciones_enviadas,
    (SELECT COALESCE(SUM(t.importe), 0) 
     FROM transaccion t 
     WHERE t.sender_user_id = u.user_id) AS monto_total_enviado
FROM usuario u;

-- Filtros dinámicos con WHERE y operadores lógicos
SELECT user_id, nombre, saldo, currency_id
FROM usuario
WHERE saldo >= 100000.00 AND currency_id = 2;

-- Tarea Plus (Lección 2): Crear una vista que muestre el Top 5 de usuarios con mayor saldo
CREATE OR REPLACE VIEW vista_top5_usuarios_saldo AS
SELECT 
    u.user_id,
    u.nombre,
    u.correo_electronico,
    u.saldo,
    m.currency_symbol AS divisa
FROM usuario u
INNER JOIN moneda m ON u.currency_id = m.currency_id
ORDER BY u.saldo DESC
LIMIT 5;

-- Consultar la vista creada
SELECT * FROM vista_top5_usuarios_saldo;
