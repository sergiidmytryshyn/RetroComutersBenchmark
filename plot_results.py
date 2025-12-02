import pandas as pd
import matplotlib.pyplot as plt

def generate_benchmark_plot(csv_filepath="benchmark_results.csv"):
    """
    Reads benchmark results from a CSV, groups them by 'Machine', and plots
    'Seconds' (Y-axis) against 'Loops' (X-axis) for each machine.
    """
    try:
        df = pd.read_csv(csv_filepath)
    except FileNotFoundError:
        print(f"Error: The file '{csv_filepath}' was not found. Please ensure it is in the same directory.")
        return
    except pd.errors.EmptyDataError:
        print("Error: The CSV file is empty.")
        return

    plot_data = df.groupby(['Loops', 'Machine'])['Seconds'].mean().reset_index()

    plt.figure(figsize=(10, 6))

    machines = plot_data['Machine'].unique()

    for machine in machines:
        machine_data = plot_data[plot_data['Machine'] == machine]

        plt.plot(
            machine_data['Loops'],
            machine_data['Seconds'],
            marker='o',
            linestyle='-',
            label=f'{machine} (Avg Time)'
        )

    plt.title('Benchmark Performance: Time vs. Number of Loops', fontsize=16, fontweight='bold')
    plt.xlabel('Number of Loops (Iterations)', fontsize=12)
    plt.ylabel('Average Execution Time (Seconds)', fontsize=12)
    plt.legend(title='Machine Type', loc='upper left')
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.tight_layout()

    plt.show()

if __name__ == "__main__":
    generate_benchmark_plot()