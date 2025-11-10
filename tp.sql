DROP DATABASE IF EXISTS gestion_utilisateurs;
CREATE DATABASE gestion_utilisateurs;

\c gestion_utilisateurs

DROP TABLE IF EXISTS utilisateur_roles;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS utilisateurs;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS logs_connexion;


CREATE TABLE utilisateurs (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    nom VARCHAR(50),
    prenom VARCHAR(50),
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT emailformat CHECK (
        email ~* '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    )
);

CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_utilisateurs_actif ON utilisateurs(actif);

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(50) UNIQUE NOT NULL,
    description VARCHAR(255),
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(50) UNIQUE NOT NULL,
    ressource VARCHAR(255),
    action VARCHAR(255),
    description VARCHAR(255)
);

CREATE TABLE utilisateur_roles (
    utilisateur_id INT REFERENCES utilisateurs(id) ON DELETE CASCADE,
    role_id INT REFERENCES roles(id) ON DELETE CASCADE,
    date_assignation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (utilisateur_id, role_id)
);

CREATE TABLE role_permissions (
    role_id INT REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INT REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    utilisateur_id INT REFERENCES utilisateurs(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    actif BOOLEAN DEFAULT TRUE
);

CREATE TABLE logs_connexion (
    id SERIAL PRIMARY KEY,
    utilisateur_id INT REFERENCES utilisateurs(id) ON DELETE SET NULL,
    email_tentative VARCHAR(255),
    date_heure TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    adresse_ip VARCHAR(45),
    user_agent TEXT,
    succes BOOLEAN,
    message TEXT
);


-- Insérer des rôles
INSERT INTO roles (nom, description) VALUES
 ('admin', 'Administrateur avec tous les droits'),
 ('moderator', 'Modérateur de contenu'),
 ('user', 'Utilisateur standard');


-- Insérer des permissions
INSERT INTO permissions (nom, ressource, action, description) VALUES
 ('read_users', 'users', 'read', 'Lire les utilisateurs'),
 ('write_users', 'users', 'write', 'Créer/modifier des utilisateurs'),
 ('delete_users', 'users', 'delete', 'Supprimer des utilisateurs'),
 ('read_posts', 'posts', 'read', 'Lire les posts'),
 ('write_posts', 'posts', 'write', 'Créer/modifier des posts'),
 ('delete_posts', 'posts', 'delete', 'Supprimer des posts');


