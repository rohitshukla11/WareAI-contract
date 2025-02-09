// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InventoryEscrow {
    address public owner;

    struct Product {
        string name;
        uint256 price;
        uint256 stock;
    }

    struct Order {
        address buyer;
        uint256 productId;
        uint256 quantity;
        uint256 amount;
        bool fulfilled;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;

    uint256 public productCount;
    uint256 public orderCount;

    event ProductAdded(uint256 productId, string name, uint256 price, uint256 stock);
    event ProductRestocked(uint256 productId, uint256 newStock);
    event OrderPlaced(uint256 orderId, address buyer, uint256 productId, uint256 quantity, uint256 amount);
    event OrderFulfilled(uint256 orderId, address buyer, uint256 productId);
    event PaymentReleased(uint256 orderId, address seller, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function addProduct(string memory name, uint256 price, uint256 stock) public onlyOwner {
        require(price > 0, "Price must be greater than zero");
        require(stock > 0, "Stock must be greater than zero");

        productCount++;
        products[productCount] = Product(name, price, stock);
        emit ProductAdded(productCount, name, price, stock);
    }

    function restockProduct(uint256 productId, uint256 additionalStock) public onlyOwner {
        require(products[productId].stock > 0, "Product does not exist");
        products[productId].stock += additionalStock;
        emit ProductRestocked(productId, products[productId].stock);
    }

    function getStock(uint256 productId) public view returns (uint256) {
        require(products[productId].stock > 0, "Product does not exist");
        return products[productId].stock;
    }

    function getAllProductStock() public view returns (string[] memory, uint256[] memory) {
        string[] memory productNames = new string[](productCount);
        uint256[] memory stockLevels = new uint256[](productCount);

        for (uint256 i = 1; i <= productCount; i++) {
            productNames[i - 1] = products[i].name;
            stockLevels[i - 1] = products[i].stock;
        }

        return (productNames, stockLevels);
    }

    function placeOrder(uint256 productId, uint256 quantity) public payable {
        require(products[productId].stock >= quantity, "Not enough stock available");
        uint256 totalPrice = products[productId].price * quantity;
        require(msg.value == totalPrice, "Incorrect payment amount");

        products[productId].stock -= quantity;
        orderCount++;
        orders[orderCount] = Order(msg.sender, productId, quantity, msg.value, false);
        
        emit OrderPlaced(orderCount, msg.sender, productId, quantity, msg.value);
    }

    function fulfillOrder(uint256 orderId, address payable seller) public onlyOwner {
        require(orders[orderId].buyer != address(0), "Order does not exist");
        require(!orders[orderId].fulfilled, "Order already fulfilled");

        orders[orderId].fulfilled = true;
        seller.transfer(orders[orderId].amount);
        
        emit OrderFulfilled(orderId, orders[orderId].buyer, orders[orderId].productId);
        emit PaymentReleased(orderId, seller, orders[orderId].amount);
    }
}
