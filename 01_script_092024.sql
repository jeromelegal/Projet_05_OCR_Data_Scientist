---------------------------------------------------Request_1-------------------------------------------------
WITH dates AS( 
	SELECT 
		MAX(o.order_approved_at) AS date_max, -- recupere la date max 
		DATE(MAX(o.order_approved_at), '-3 months') AS three_month_ago -- calcul 3 mois avant la date max
	FROM orders o
)
SELECT o.order_id, o.order_approved_at, o.order_delivered_customer_date - o.order_estimated_delivery_date AS delay FROM orders o
WHERE 
	o.order_status = 'delivered' -- commandes livrées
AND
	o.order_approved_at BETWEEN (SELECT three_month_ago from dates) AND (SELECT date_max from dates) -- commandes de - de 3 mois
AND
	o.order_delivered_customer_date > DATE(o.order_estimated_delivery_date, '+3 day'); -- commandes en retard de plus de 3 jours




---------------------------------------------------Request_2-------------------------------------------------

WITH payments_data AS ( --creation d'une table avec les commandes, les paiements, les vendeurs et le statut des commandes
	SELECT oi.order_id, oi.seller_id, op.payment_value, o.order_status FROM order_items oi
	JOIN order_pymts op ON oi.order_id = op.order_id 
	JOIN orders o ON oi.order_id = o.order_id
	)
SELECT pd.seller_id, SUM(pd.payment_value) AS sales_revenue --recupere le seller_id et calcul le chiffre d'affaires
FROM payments_data pd
WHERE pd.order_status = 'delivered' --filtre sur les commandes livrees
GROUP by pd.seller_id --groupe par vendeur
HAVING sales_revenue > 100000; --filtre CA superieur à 100000



---------------------------------------------------Request_3-------------------------------------------------

WITH max_date AS ( --recupere la date la plus recente du dataset
	SELECT
		MAX(o.order_purchase_timestamp) AS date_max FROM orders o 
	),
	first_order_date AS ( --table des dates des premieres commandes de chaque vendeur
	SELECT 
		o.order_id, MIN(o.order_purchase_timestamp) AS first_purchase_date, oi.seller_id FROM orders o 
		JOIN order_items oi ON o.order_id = oi.order_id
		GROUP BY oi.seller_id
	),
	young_sellers AS ( --table de la liste des vendeurs avec - 3 mois d'anciennete
	SELECT 
		fod.seller_id, md.date_max FROM first_order_date fod
		CROSS JOIN max_date md
		WHERE fod.first_purchase_date > DATE(md.date_max, '-3 months')
	)
SELECT ys.seller_id, COUNT(oi.order_id) AS qty_orders FROM young_sellers ys --liste des jeunes vendeurs et le nombre de commandes
JOIN order_items oi ON ys.seller_id = oi.seller_id 
GROUP BY ys.seller_id
HAVING COUNT(oi.order_id) > 30; --filtre sur les vendeurs avec plus de 30 commandes



---------------------------------------------------Request_4-------------------------------------------------

WITH date_year AS ( --calcul de la date 1 an avant la date la plus recente du dataset
	SELECT
		DATE(MAX(o.order_purchase_timestamp), '-12 month') AS date_max FROM orders o 
	),
	sellers_list AS ( --table des review_score de moins de 12 mois avec code_postal
	SELECT
		ore.order_id, ore.review_score, ore.review_creation_date, oi.seller_id, s.seller_zip_code_prefix AS postal_code, dy.date_max FROM order_reviews ore
	JOIN order_items oi ON ore.order_id = oi.order_id
	JOIN sellers s ON oi.seller_id = s.seller_id
	CROSS JOIN date_year dy
	WHERE ore.review_creation_date > dy.date_max
	)
SELECT sl.postal_code, COUNT(sl.review_score) AS review_count, AVG(sl.review_score) AS mean_score --affiche code postal, nombre de review et moyenne des reviews
FROM sellers_list sl
GROUP BY sl.postal_code --groupe par code postal
HAVING COUNT(sl.review_score) > 30
ORDER BY mean_score ASC --rangement par score moyen les plus faibles 
LIMIT 5;