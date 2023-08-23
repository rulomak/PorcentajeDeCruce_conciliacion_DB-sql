Create database if not exists Prueba_bproSys;

use Prueba_bproSys;

CREATE TABLE IF NOT EXISTS Bansur(
	TARJETA BIGINT, 
	TIPO_TRX VARCHAR(15),
    MONTO DECIMAL(10,2),
    FECHA_TRANSACCION VARCHAR(15),
    CODIGO_AUTORIZACION VARCHAR(15),
    ID_ADQUIRIENTE BIGINT,
    FECHA_RECEPCION DATE
    );
    
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\BANSUR.csv'
INTO TABLE Bansur
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SELECT count(*) FROM Bansur;


CREATE TABLE IF NOT EXISTS Clap(
	INICIO6_TARJETA BIGINT NULL, 
	FINAL4_TARJETA BIGINT,
    TIPO_TRX VARCHAR(15),
	MONTO DECIMAL(10,2),
    FECHA_TRANSACCION VARCHAR(30),
    CODIGO_AUTORIZACION varchar(15),
    ID_BANCO VARCHAR(256),
    FECHA_RECEPCION_BANCO DATE
    );
    
    
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\CLAP.csv'
INTO TABLE Clap
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@INICIO6_TARJETA, FINAL4_TARJETA, TIPO_TRX, MONTO, FECHA_TRANSACCION, CODIGO_AUTORIZACION, ID_BANCO, FECHA_RECEPCION_BANCO)  -- Asegúrate de incluir todos los nombres de columnas en orden
SET INICIO6_TARJETA = NULLIF(@INICIO6_TARJETA, '');


select * from Clap;
select count(*) from Clap;

-- 1 ) Escriba el código de SQL que le permite conocer el monto y la cantidad de las transacciones que SIMETRIK considera como conciliables para la base de CLAP

SELECT
    SUM(MONTO) AS MontoTotal,
    COUNT(*) AS CantidadTransacciones
FROM
    Clap AS c
WHERE TIPO_TRX = 'PAGADA'
    AND EXISTS (
        SELECT
            1
        FROM
            Bansur AS b
        WHERE
            c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
            AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
            AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
            
            AND (
                c.MONTO = b.MONTO
                OR ABS(c.MONTO - b.MONTO) <= 0.99
            )
            AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
			AND TIPO_TRX = 'PAGO'
    );
    
    

-- 2 ) Escriba el código de SQL que le permite conocer el monto y la cantidad de las transacciones que SIMETRIK considera como conciliables para la base de BANSUR


SELECT
    SUM(MONTO) AS MontoTotal,
    COUNT(*) AS CantidadTransacciones
FROM
    Bansur AS b
WHERE TIPO_TRX = 'PAGO'
    AND EXISTS (
        SELECT
            1
        FROM
            Clap AS c
        WHERE
            c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
            AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
            AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
            AND (
                c.MONTO = b.MONTO
                OR ABS(c.MONTO - b.MONTO) <= 0.99
            )
            AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
            AND TIPO_TRX = 'PAGADA'
    );
    
    
-- 4) Teniendo en cuenta los criterios de cruce entre ambas bases conciliables, escriba una sentencia de SQL que contenga la información de CLAP y BANSUR; agregue una columna en la que se evidencie si la transacción cruzó o no con su contrapartida y una columna en la 
-- que se inserte un ID autoincremental para el control de la conciliación
    
    
     SELECT
    @row_number := @row_number + 1 AS CONCILIACION_ID,
    c.*, b.*,
    CASE
        WHEN
            c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
            AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
            AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
            AND (
                c.MONTO = b.MONTO
                OR ABS(c.MONTO - b.MONTO) <= 0.99
            )
            AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
        THEN 'Cruzó'
        ELSE 'No cruzó'
    END AS CONCILIACION_ESTADO
FROM
    (SELECT @row_number := 0) AS init,
    Clap AS c
LEFT JOIN
    Bansur AS b
ON
    c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
    AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
    AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
    AND (
        c.MONTO = b.MONTO
        OR ABS(c.MONTO - b.MONTO) <= 0.99
    )
    AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d');
    
    
    
-- 5) Diseñe un código que calcule el porcentaje de transacciones de la base conciliable de CLAP cruzó contra la liquidación de BANSUR.
    
    SELECT
    (COUNT(CASE WHEN CONCILIACION_ESTADO = 'Cruzó' THEN 1 ELSE NULL END) / COUNT(*)) * 100 AS PorcentajeCruce
FROM
    (
        SELECT
           c.CODIGO_AUTORIZACION AS Clap_CODIGO_AUTORIZACION, 
           c.INICIO6_TARJETA, c.FINAL4_TARJETA, c.MONTO, 
           c.FECHA_TRANSACCION AS Clap_FECHA_TRANSACCION, 
           b.CODIGO_AUTORIZACION AS Bansur_CODIGO_AUTORIZACION, 
           b.TARJETA, b.FECHA_TRANSACCION AS Bansur_FECHA_TRANSACCION,
            CASE
                WHEN
                    c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
                    AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
                    AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
                    AND (
                        c.MONTO = b.MONTO
                        OR ABS(c.MONTO - b.MONTO) <= 0.99
                    )
                    AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
                THEN 'Cruzó'
                ELSE 'No cruzó'
            END AS CONCILIACION_ESTADO
        FROM
            Clap AS c
        LEFT JOIN
            Bansur AS b
        ON
            c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
            AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
            AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
            AND (
                c.MONTO = b.MONTO
                OR ABS(c.MONTO - b.MONTO) <= 0.99
            )
            AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
    )AS ConciliacionResultado;
    
    
    
    
-- 6) Diseñe un código que calcule el porcentaje de transacciones de la base conciliable de BANSUR no cruzó contra la liquidación de CLAP
    
    SELECT
    (COUNT(CASE WHEN CONCILIACION_ESTADO = 'No cruzó' THEN 1 ELSE NULL END) / COUNT(*)) * 100 AS PorcentajeNoCruce
FROM
    (
        SELECT
            b.CODIGO_AUTORIZACION AS Bansur_CODIGO_AUTORIZACION, 
            b.TARJETA, b.FECHA_TRANSACCION AS Bansur_FECHA_TRANSACCION, 
            c.CODIGO_AUTORIZACION AS Clap_CODIGO_AUTORIZACION, c.INICIO6_TARJETA, 
            c.FINAL4_TARJETA, c.MONTO, c.FECHA_TRANSACCION AS Clap_FECHA_TRANSACCION,
            CASE
                WHEN
                    c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
                    AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
                    AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
                    AND (
                        c.MONTO = b.MONTO
                        OR ABS(c.MONTO - b.MONTO) <= 0.99
                    )
                    AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
                THEN 'Cruzó'
                ELSE 'No cruzó'
            END AS CONCILIACION_ESTADO
        FROM
            Bansur AS b
        LEFT JOIN
            Clap AS c
        ON
            c.CODIGO_AUTORIZACION = b.CODIGO_AUTORIZACION
            AND c.INICIO6_TARJETA = SUBSTRING(b.TARJETA, 1, 6)
            AND c.FINAL4_TARJETA = SUBSTRING(b.TARJETA, -4)
            AND (
                c.MONTO = b.MONTO
                OR ABS(c.MONTO - b.MONTO) <= 0.99
            )
            AND DATE_FORMAT(STR_TO_DATE(c.FECHA_TRANSACCION, '%Y-%m-%d %H:%i:%s.%f'), '%Y%m%d') = STR_TO_DATE(b.FECHA_TRANSACCION, '%Y%m%d')
    )AS ConciliacionResultado;
    
    
    
    
    
    

    
    

