#!/usr/bin/env python3
"""
Sample Data Generator for DataWorks & MaxCompute Practice Project
Generates realistic sample data for testing and learning purposes

Usage:
    python data_generator.py --table customers --records 10000 --output customers_large.csv
    python data_generator.py --table orders --records 50000 --start-date 2023-01-01 --end-date 2024-12-31
    python data_generator.py --table all --records 1000  # Generate all tables with 1000 records each
"""

import csv
import random
import argparse
import os
from datetime import datetime, timedelta
from typing import List, Dict, Any
import uuid


class DataGenerator:
    def __init__(self):
        """Initialize the data generator with sample data pools."""
        
        # Sample data pools
        self.first_names = [
            'John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily', 'James', 'Emma',
            'Robert', 'Lisa', 'William', 'Jennifer', 'Thomas', 'Maria', 'Christopher',
            'Michelle', 'Daniel', 'Jessica', 'Matthew', 'Ashley', 'Anthony', 'Amanda',
            'Mark', 'Melissa', 'Steven', 'Deborah', 'Paul', 'Stephanie', 'Andrew',
            'Dorothy', 'Kenneth', 'Amy', 'Joshua', 'Angela', 'Kevin', 'Helen',
            'Brian', 'Brenda', 'George', 'Julie', 'Edward', 'Joyce', 'Ronald',
            'Virginia', 'Timothy', 'Victoria', 'Jason', 'Kelly', 'Jeffrey', 'Christina'
        ]
        
        self.last_names = [
            'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller',
            'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez',
            'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin',
            'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez', 'Clark',
            'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King',
            'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green',
            'Adams', 'Nelson', 'Baker', 'Hall', 'Rivera', 'Campbell', 'Mitchell',
            'Carter', 'Roberts'
        ]
        
        self.countries = [
            'USA', 'Canada', 'UK', 'Germany', 'France', 'Spain', 'Italy',
            'Australia', 'Japan', 'South Korea', 'China', 'India', 'Brazil',
            'Mexico', 'Netherlands', 'Sweden', 'Norway', 'Denmark', 'Finland'
        ]
        
        self.cities = {
            'USA': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia'],
            'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa', 'Edmonton'],
            'UK': ['London', 'Manchester', 'Birmingham', 'Liverpool', 'Leeds', 'Sheffield'],
            'Germany': ['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt', 'Stuttgart'],
            'France': ['Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Nantes'],
            'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide', 'Canberra'],
            'Japan': ['Tokyo', 'Osaka', 'Kyoto', 'Yokohama', 'Kobe', 'Nagoya']
        }
        
        self.age_groups = ['18-24', '25-34', '35-44', '45-54', '55-64', '65+']
        
        self.product_categories = [
            'Electronics', 'Fashion', 'Home', 'Sports', 'Books', 'Automotive',
            'Health', 'Beauty', 'Garden', 'Toys', 'Jewelry', 'Music'
        ]
        
        self.product_names = {
            'Electronics': ['Smartphone', 'Laptop', 'Tablet', 'Headphones', 'Speaker', 'Camera', 'TV', 'Gaming Console'],
            'Fashion': ['T-Shirt', 'Jeans', 'Dress', 'Shoes', 'Jacket', 'Hat', 'Watch', 'Sunglasses'],
            'Home': ['Coffee Maker', 'Blender', 'Vacuum', 'Lamp', 'Chair', 'Table', 'Bed', 'Sofa'],
            'Sports': ['Running Shoes', 'Yoga Mat', 'Bicycle', 'Tennis Racket', 'Soccer Ball', 'Dumbbells']
        }
        
        self.brands = [
            'TechBrand', 'SportMax', 'HomeEssentials', 'FashionForward', 'GadgetPro',
            'StyleMaster', 'ComfortZone', 'PowerGear', 'UrbanStyle', 'PremiumChoice'
        ]
        
        self.order_statuses = ['completed', 'processing', 'shipped', 'cancelled', 'pending']
        self.payment_methods = ['credit_card', 'debit_card', 'paypal', 'bank_transfer', 'cash']
        
        self.traffic_sources = ['google', 'facebook', 'direct', 'email', 'twitter', 'linkedin', 'youtube', 'bing']
        self.device_types = ['desktop', 'mobile', 'tablet']
        self.browsers = ['chrome', 'firefox', 'safari', 'edge', 'opera']
        
    def generate_customers(self, num_records: int) -> List[Dict[str, Any]]:
        """Generate customer data."""
        customers = []
        
        for i in range(num_records):
            first_name = random.choice(self.first_names)
            last_name = random.choice(self.last_names)
            country = random.choice(self.countries)
            city = random.choice(self.cities.get(country, ['Unknown City']))
            
            customer = {
                'customer_id': f'CUST{i+1:06d}',
                'first_name': first_name,
                'last_name': last_name,
                'email': f'{first_name.lower()}.{last_name.lower()}@email.com',
                'phone': self.generate_phone_number(country),
                'registration_date': self.random_date(datetime(2020, 1, 1), datetime(2024, 12, 31)),
                'country': country,
                'city': city,
                'age_group': random.choice(self.age_groups)
            }
            customers.append(customer)
        
        return customers
    
    def generate_products(self, num_records: int) -> List[Dict[str, Any]]:
        """Generate product data."""
        products = []
        
        for i in range(num_records):
            category = random.choice(self.product_categories)
            product_names = self.product_names.get(category, ['Generic Product'])
            base_name = random.choice(product_names)
            
            # Generate realistic pricing
            base_cost = random.uniform(10, 500)
            markup = random.uniform(1.5, 3.0)
            price = round(base_cost * markup, 2)
            
            product = {
                'product_id': f'PROD{i+1:06d}',
                'product_name': f'{random.choice(self.brands)} {base_name}',
                'category': category,
                'sub_category': self.generate_subcategory(category),
                'brand': random.choice(self.brands),
                'price': price,
                'cost': round(base_cost, 2),
                'supplier_id': f'SUP{random.randint(1, 20):03d}',
                'launch_date': self.random_date(datetime(2020, 1, 1), datetime(2024, 6, 30))
            }
            products.append(product)
        
        return products
    
    def generate_orders(self, num_records: int, customer_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Generate order data."""
        if not customer_ids:
            customer_ids = [f'CUST{i+1:06d}' for i in range(1000)]
        
        orders = []
        
        for i in range(num_records):
            order_date = self.random_date(datetime(2024, 1, 1), datetime(2024, 6, 30))
            total_amount = round(random.uniform(25, 500), 2)
            shipping_cost = 0 if total_amount > 100 else round(random.uniform(5, 25), 2)
            
            order = {
                'order_id': f'ORD{i+1:06d}',
                'customer_id': random.choice(customer_ids),
                'order_date': order_date,
                'order_status': random.choice(self.order_statuses),
                'total_amount': total_amount,
                'shipping_cost': shipping_cost,
                'payment_method': random.choice(self.payment_methods),
                'shipping_address': self.generate_address()
            }
            orders.append(order)
        
        return orders
    
    def generate_order_items(self, num_records: int, order_ids: List[str] = None, 
                           product_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Generate order items data."""
        if not order_ids:
            order_ids = [f'ORD{i+1:06d}' for i in range(10000)]
        if not product_ids:
            product_ids = [f'PROD{i+1:06d}' for i in range(1000)]
        
        order_items = []
        
        for i in range(num_records):
            quantity = random.randint(1, 5)
            unit_price = round(random.uniform(10, 200), 2)
            discount_amount = 0 if random.random() > 0.3 else round(unit_price * random.uniform(0.05, 0.25), 2)
            line_total = round((unit_price * quantity) - discount_amount, 2)
            
            item = {
                'order_item_id': f'ITEM{i+1:06d}',
                'order_id': random.choice(order_ids),
                'product_id': random.choice(product_ids),
                'quantity': quantity,
                'unit_price': unit_price,
                'discount_amount': discount_amount,
                'line_total': line_total
            }
            order_items.append(item)
        
        return order_items
    
    def generate_web_sessions(self, num_records: int) -> List[Dict[str, Any]]:
        """Generate web session data."""
        sessions = []
        
        for i in range(num_records):
            session_start = self.random_date(datetime(2024, 1, 1), datetime(2024, 6, 30))
            duration = random.randint(30, 3600)  # 30 seconds to 1 hour
            session_end = session_start + timedelta(seconds=duration)
            page_views = random.randint(1, 25)
            
            session = {
                'session_id': f'SES{i+1:06d}',
                'user_id': f'USR{random.randint(1, num_records//10):06d}',
                'session_start': session_start,
                'session_end': session_end,
                'page_views': page_views,
                'session_duration_seconds': duration,
                'traffic_source': random.choice(self.traffic_sources),
                'device_type': random.choice(self.device_types),
                'browser': random.choice(self.browsers),
                'country': random.choice(self.countries)
            }
            sessions.append(session)
        
        return sessions
    
    def generate_page_views(self, num_records: int, session_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Generate page view data."""
        if not session_ids:
            session_ids = [f'SES{i+1:06d}' for i in range(10000)]
        
        page_urls = [
            '/home', '/products', '/about', '/contact', '/cart', '/checkout',
            '/search', '/category/electronics', '/category/fashion', '/category/home',
            '/product/detail', '/user/profile', '/user/orders', '/blog', '/support'
        ]
        
        page_views = []
        
        for i in range(num_records):
            timestamp = self.random_date(datetime(2024, 1, 1), datetime(2024, 6, 30))
            time_on_page = random.randint(5, 600)  # 5 seconds to 10 minutes
            
            page_view = {
                'page_view_id': f'PV{i+1:06d}',
                'session_id': random.choice(session_ids),
                'user_id': f'USR{random.randint(1, 10000):06d}',
                'page_url': random.choice(page_urls),
                'page_title': self.generate_page_title(),
                'timestamp': timestamp,
                'time_on_page_seconds': time_on_page,
                'referrer_url': self.generate_referrer(),
                'exit_page': random.choice([True, False])
            }
            page_views.append(page_view)
        
        return page_views
    
    def generate_user_events(self, num_records: int, session_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Generate user event data."""
        if not session_ids:
            session_ids = [f'SES{i+1:06d}' for i in range(10000)]
        
        event_types = ['click', 'scroll', 'hover', 'form_fill', 'search', 'download', 'video_play']
        
        events = []
        
        for i in range(num_records):
            event = {
                'event_id': f'EVT{i+1:06d}',
                'session_id': random.choice(session_ids),
                'user_id': f'USR{random.randint(1, 10000):06d}',
                'event_type': random.choice(event_types),
                'event_timestamp': self.random_date(datetime(2024, 1, 1), datetime(2024, 6, 30)),
                'page_url': f'/page_{random.randint(1, 100)}',
                'element_id': f'element_{random.randint(1, 1000)}',
                'element_type': random.choice(['button', 'link', 'input', 'image', 'video']),
                'event_data': f'data_{random.randint(1, 10000)}'
            }
            events.append(event)
        
        return events
    
    def generate_phone_number(self, country: str) -> str:
        """Generate a realistic phone number based on country."""
        if country == 'USA':
            return f'+1-{random.randint(200, 999)}-{random.randint(200, 999)}-{random.randint(1000, 9999)}'
        elif country == 'UK':
            return f'+44-20-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}'
        elif country == 'Germany':
            return f'+49-30-{random.randint(100, 999)}-{random.randint(1000, 9999)}'
        else:
            return f'+{random.randint(1, 999)}-{random.randint(100, 999)}-{random.randint(1000, 9999)}'
    
    def generate_address(self) -> str:
        """Generate a random address."""
        street_num = random.randint(1, 9999)
        street_names = ['Main St', 'Oak Ave', 'Pine Rd', 'First St', 'Second Ave', 'Park Blvd']
        street = random.choice(street_names)
        return f'{street_num} {street}'
    
    def generate_subcategory(self, category: str) -> str:
        """Generate subcategory based on main category."""
        subcategories = {
            'Electronics': ['Audio', 'Video', 'Computer', 'Mobile', 'Gaming'],
            'Fashion': ['Clothing', 'Footwear', 'Accessories', 'Jewelry'],
            'Home': ['Kitchen', 'Furniture', 'Decor', 'Appliances'],
            'Sports': ['Fitness', 'Outdoor', 'Team Sports', 'Water Sports']
        }
        return random.choice(subcategories.get(category, ['General']))
    
    def generate_page_title(self) -> str:
        """Generate realistic page titles."""
        titles = [
            'Home Page', 'Product Catalog', 'About Us', 'Contact Us',
            'Shopping Cart', 'Checkout', 'Search Results', 'User Profile',
            'Order History', 'Product Details', 'Category Page', 'Blog Post'
        ]
        return random.choice(titles)
    
    def generate_referrer(self) -> str:
        """Generate realistic referrer URLs."""
        referrers = [
            'https://google.com', 'https://facebook.com', 'https://twitter.com',
            'direct', 'https://linkedin.com', 'https://youtube.com', 'email',
            'https://bing.com', 'https://reddit.com'
        ]
        return random.choice(referrers)
    
    def random_date(self, start_date: datetime, end_date: datetime) -> datetime:
        """Generate a random date between start_date and end_date."""
        time_between = end_date - start_date
        days_between = time_between.days
        random_days = random.randrange(days_between)
        random_seconds = random.randrange(24 * 60 * 60)  # Random time within the day
        return start_date + timedelta(days=random_days, seconds=random_seconds)
    
    def save_to_csv(self, data: List[Dict[str, Any]], filename: str):
        """Save data to CSV file."""
        if not data:
            print(f"No data to save for {filename}")
            return
        
        # Ensure data directory exists
        os.makedirs('generated_data', exist_ok=True)
        
        filepath = os.path.join('generated_data', f'{filename}.csv')
        
        with open(filepath, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = data[0].keys()
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for row in data:
                # Format datetime objects
                formatted_row = {}
                for key, value in row.items():
                    if isinstance(value, datetime):
                        formatted_row[key] = value.strftime('%Y-%m-%d %H:%M:%S')
                    else:
                        formatted_row[key] = value
                writer.writerow(formatted_row)
        
        print(f"Generated {len(data)} records and saved to {filepath}")


def main():
    parser = argparse.ArgumentParser(description='Generate sample data for DataWorks & MaxCompute')
    parser.add_argument('--table', choices=['customers', 'products', 'orders', 'order_items', 
                                          'web_sessions', 'page_views', 'user_events', 'all'],
                       required=True, help='Table to generate data for')
    parser.add_argument('--records', type=int, default=1000, help='Number of records to generate')
    parser.add_argument('--output', help='Output filename (without extension)')
    parser.add_argument('--start-date', help='Start date for date ranges (YYYY-MM-DD)')
    parser.add_argument('--end-date', help='End date for date ranges (YYYY-MM-DD)')
    
    args = parser.parse_args()
    
    generator = DataGenerator()
    
    if args.table == 'all':
        # Generate all tables
        print("Generating all tables...")
        
        # Generate in dependency order
        customers = generator.generate_customers(args.records)
        generator.save_to_csv(customers, 'customers_generated')
        
        products = generator.generate_products(args.records)
        generator.save_to_csv(products, 'products_generated')
        
        customer_ids = [c['customer_id'] for c in customers]
        orders = generator.generate_orders(args.records * 2, customer_ids)
        generator.save_to_csv(orders, 'orders_generated')
        
        order_ids = [o['order_id'] for o in orders]
        product_ids = [p['product_id'] for p in products]
        order_items = generator.generate_order_items(args.records * 3, order_ids, product_ids)
        generator.save_to_csv(order_items, 'order_items_generated')
        
        web_sessions = generator.generate_web_sessions(args.records)
        generator.save_to_csv(web_sessions, 'web_sessions_generated')
        
        session_ids = [s['session_id'] for s in web_sessions]
        page_views = generator.generate_page_views(args.records * 5, session_ids)
        generator.save_to_csv(page_views, 'page_views_generated')
        
        user_events = generator.generate_user_events(args.records * 3, session_ids)
        generator.save_to_csv(user_events, 'user_events_generated')
        
    else:
        # Generate specific table
        output_name = args.output or f'{args.table}_generated'
        
        if args.table == 'customers':
            data = generator.generate_customers(args.records)
        elif args.table == 'products':
            data = generator.generate_products(args.records)
        elif args.table == 'orders':
            data = generator.generate_orders(args.records)
        elif args.table == 'order_items':
            data = generator.generate_order_items(args.records)
        elif args.table == 'web_sessions':
            data = generator.generate_web_sessions(args.records)
        elif args.table == 'page_views':
            data = generator.generate_page_views(args.records)
        elif args.table == 'user_events':
            data = generator.generate_user_events(args.records)
        
        generator.save_to_csv(data, output_name)


if __name__ == '__main__':
    main()

"""
Example Usage:

# Generate 10,000 customers
python data_generator.py --table customers --records 10000 --output customers_large

# Generate 50,000 orders
python data_generator.py --table orders --records 50000

# Generate all tables with 5,000 records each
python data_generator.py --table all --records 5000

# Generate web sessions for specific date range
python data_generator.py --table web_sessions --records 100000 --start-date 2024-01-01 --end-date 2024-06-30

The generated files will be saved in the 'generated_data' directory.
"""