CREATE TABLE utilisateurs (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nom VARCHAR(100),
    prenom VARCHAR(100),
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_utilisateurs_actif ON utilisateurs(actif);

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(100) UNIQUE NOT NULL,
    ressource VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE (ressource, action)
);

CREATE TABLE utilisateur_roles (
    utilisateur_id INT NOT NULL,
    role_id INT NOT NULL,
    date_assignation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (utilisateur_id, role_id),
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
);

CREATE TABLE role_permissions (
    role_id INT NOT NULL,
    permission_id INT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
    FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    utilisateur_id INT NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    actif BOOLEAN DEFAULT true,
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE CASCADE
);

CREATE TABLE logs_connexion (
    id SERIAL PRIMARY KEY,
    utilisateur_id INT,
    email_tentative VARCHAR(255) NOT NULL,
    date_heure TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    adresse_ip VARCHAR(45),
    user_agent TEXT,
    succes BOOLEAN NOT NULL,
    message TEXT,
    FOREIGN KEY (utilisateur_id) REFERENCES utilisateurs(id) ON DELETE SET NULL
);


INSERT INTO roles (nom, description) VALUES
    ('admin', 'Administrateur avec tous les droits'),
    ('moderator', 'Modérateur de contenu'),
    ('user', 'Utilisateur standard');

INSERT INTO permissions (nom, ressource, action, description) VALUES
    ('read_users', 'users', 'read', 'Lire les utilisateurs'),
    ('write_users', 'users', 'write', 'Créer/modifier des utilisateurs'),
    ('delete_users', 'users', 'delete', 'Supprimer des utilisateurs'),
    ('read_posts', 'posts', 'read', 'Lire les posts'),
    ('write_posts', 'posts', 'write', 'Créer/modifier des posts'),
    ('delete_posts', 'posts', 'delete', 'Supprimer des posts');
   

INSERT INTO role_permissions (role_id, permission_id) VALUES
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'read_users')),
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'write_users')),
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'delete_users')),
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'read_posts')),
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'write_posts')),
    ((SELECT id FROM roles WHERE nom = 'admin'), (SELECT id FROM permissions WHERE nom = 'delete_posts')),

    ((SELECT id FROM roles WHERE nom = 'moderator'), (SELECT id FROM permissions WHERE nom = 'read_users')),
    ((SELECT id FROM roles WHERE nom = 'moderator'), (SELECT id FROM permissions WHERE nom = 'read_posts')),
    ((SELECT id FROM roles WHERE nom = 'moderator'), (SELECT id FROM permissions WHERE nom = 'write_posts')),
    ((SELECT id FROM roles WHERE nom = 'moderator'), (SELECT id FROM permissions WHERE nom = 'delete_posts')),

    ((SELECT id FROM roles WHERE nom = 'user'), (SELECT id FROM permissions WHERE nom = 'read_users')),
    ((SELECT id FROM roles WHERE nom = 'user'), (SELECT id FROM permissions WHERE nom = 'read_posts')),
    ((SELECT id FROM roles WHERE nom = 'user'), (SELECT id FROM permissions WHERE nom = 'write_posts'));


CREATE OR REPLACE FUNCTION utilisateur_a_permission(
    p_utilisateur_id INT,
    p_ressource VARCHAR,
    p_action VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM utilisateurs u
        INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
        INNER JOIN role_permissions rp ON ur.role_id = rp.role_id
        INNER JOIN permissions p ON rp.permission_id = p.id
        WHERE u.id = p_utilisateur_id
          AND u.actif = TRUE
          AND p.ressource = p_ressource
          AND p.action = p_action
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION est_token_valide(p_token VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM sessions s
        INNER JOIN utilisateurs u ON s.utilisateur_id = u.id
        WHERE s.token = p_token
          AND s.actif = TRUE
          AND s.date_expiration > CURRENT_TIMESTAMP
          AND u.actif = TRUE
    );
END;
$$ LANGUAGE plpgsql;

SELECT
    u.id,
    u.email,
    u.nom,
    u.prenom,
    u.actif,
    u.date_creation,
    COALESCE(array_agg(r.nom) FILTER (WHERE r.nom IS NOT NULL), ARRAY[]::VARCHAR[]) AS roles
FROM utilisateurs u
LEFT JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
LEFT JOIN roles r ON ur.role_id = r.id
WHERE u.id = 1
GROUP BY u.id, u.email, u.nom, u.prenom, u.actif, u.date_creation;

SELECT DISTINCT
    u.id AS utilisateur_id,
    u.email,
    p.nom AS permission,
    p.ressource,
    p.action
FROM utilisateurs u
INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
INNER JOIN role_permissions rp ON ur.role_id = rp.role_id
INNER JOIN permissions p ON rp.permission_id = p.id
WHERE u.id = 1
ORDER BY p.ressource, p.action;

SELECT
    r.nom AS role,
    COUNT(DISTINCT ur.utilisateur_id) AS nombre_utilisateurs
FROM roles r
LEFT JOIN utilisateur_roles ur ON r.id = ur.role_id
GROUP BY r.id, r.nom
ORDER BY nombre_utilisateurs DESC;

SELECT
    u.id,
    u.email,
    array_agg(r.nom) AS roles
FROM utilisateurs u
INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
INNER JOIN roles r ON ur.role_id = r.id
WHERE r.nom IN ('admin', 'moderator')
GROUP BY u.id, u.email
HAVING COUNT(DISTINCT r.nom) = 2;

SELECT
    DATE(date_heure) AS jour,
    COUNT(*) AS tentatives_echouees
FROM logs_connexion
WHERE succes = FALSE
  AND date_heure >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(date_heure)
ORDER BY jour DESC;