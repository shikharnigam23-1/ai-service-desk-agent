-- 04_seed_category_routing.sql — category -> resolver group (FR-11, NFR-11, D-60, D-75). Run fourth.
-- Category names are copied exactly from Topic_group in the Kaggle "IT Service Ticket
-- Classification" dataset (all_tickets_processed_improved_v3.csv), so they also form the
-- fixed category list in the AI output contract (SRS §6.2).
-- 7 resolver groups: Access and Administrative rights share IAM (D-75).
--
-- Safe to re-run: an upsert. It adds missing rows and resets resolver_group to the values below.
-- It does not delete rows, because tickets and kb_articles may already reference a category.

INSERT INTO category_routing (category, resolver_group) VALUES
    ('Hardware',              'End-User Computing'),
    ('Access',                'Identity & Access Mgmt (IAM)'),
    ('Administrative rights', 'Identity & Access Mgmt (IAM)'),
    ('Storage',               'Infrastructure & Storage'),
    ('HR Support',            'HR Systems Support'),
    ('Purchase',              'IT Procurement'),
    ('Internal Project',      'Application Support / PMO'),
    ('Miscellaneous',         'L1 Service Desk (general queue)')
ON CONFLICT (category) DO UPDATE
    SET resolver_group = EXCLUDED.resolver_group;
