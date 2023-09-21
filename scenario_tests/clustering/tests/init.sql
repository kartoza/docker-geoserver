 CREATE TABLE IF NOT EXISTS states (
                    id integer not null
                        constraint pkey primary key,
                    geom geometry(Point, 4326),
                    name varchar(30),
                    alias varchar(30),
                    description varchar(255)
                );

INSERT INTO states (id, geom, name, alias, description)
                VALUES 
                (
                    1,
                    st_setsrid(st_point(107.6097, 6.9120), 4326),
                    'Bandung',
                    'Paris van Java',
                    'Asia-Africa conference was held here'                     
                ) ON CONFLICT DO NOTHING;

                
